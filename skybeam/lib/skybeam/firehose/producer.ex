defmodule Skybeam.Firehose.Producer do
  use GenStage
  require Logger

  def start_link(_opts) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def notify_events(events) do
    # Find the producer process started by Broadway
    producers = Broadway.producer_names(Skybeam.Firehose.Pipeline)
    
    case producers do
      [producer_name] ->
        GenStage.cast(producer_name, {:notify, events})
      [] ->
        Logger.warning("notify_events: No producers found for Skybeam.Firehose.Pipeline")
      _ ->
        Logger.warning("notify_events: Multiple producers found: #{inspect(producers)}")
    end
  end

  @impl true
  def init(_opts) do
    {:producer, {:queue.new(), 0}}
  end

  @impl true
  def handle_cast({:notify, events}, {queue, demand}) do
    dispatch_events(queue, demand, events)
  end

  @impl true
  def handle_demand(incoming_demand, {queue, demand}) do
    dispatch_events(queue, demand + incoming_demand, [])
  end

  defp dispatch_events(queue, demand, events) do
    # Add new events to queue
    queue = Enum.reduce(events, queue, &:queue.in/2)

    # Dispatch as many as possible based on demand
    {events_to_dispatch, new_queue, new_demand} =
      take_events(queue, demand, [])


    {:noreply, events_to_dispatch, {new_queue, new_demand}}
  end

  defp take_events(queue, 0, acc), do: {Enum.reverse(acc), queue, 0}
  defp take_events(queue, demand, acc) do
    case :queue.out(queue) do
      {{:value, event}, new_queue} ->
        take_events(new_queue, demand - 1, [event | acc])

      {:empty, _} ->
        {Enum.reverse(acc), queue, demand}
    end
  end
end
