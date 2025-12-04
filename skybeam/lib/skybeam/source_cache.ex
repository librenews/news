defmodule Skybeam.SourceCache do
  use GenServer
  require Logger

  @table_name :source_dids
  @refresh_interval 30_000

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def exists?(did) do
    :ets.member(@table_name, did)
  end

  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  # Server Callbacks

  @impl true
  def init(_state) do
    Logger.info("SourceCache starting...")
    :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true])
    schedule_refresh()
    {:ok, %{}}
  end

  @impl true
  def handle_cast(:refresh, state) do
    refresh_dids()
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    refresh_dids()
    schedule_refresh()
    {:noreply, state}
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp refresh_dids do
    Logger.info("Refreshing source DIDs from Feedbrainer...")

    case fetch_dids() do
      {:ok, dids} ->
        update_table(dids)
        Logger.info("Refreshed source DIDs. Count: #{length(dids)}")

      {:error, reason} ->
        Logger.error("Failed to refresh source DIDs: #{inspect(reason)}")
    end
  end

  defp fetch_dids do
    base_url = System.get_env("FEEDBRAINER_URL") || "http://feedbrainer:3000"
    url = "#{base_url}/api/sources"
    Logger.info("Fetching DIDs from: #{url}")

    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        Logger.info("Fetched #{length(body)} DIDs")
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Feedbrainer API returned status #{status}. Body: #{inspect(body)}")
        {:error, "Feedbrainer API returned status #{status}"}

      {:error, exception} ->
        Logger.error("Req failed: #{inspect(exception)}")
        {:error, exception}
    end
  end

  defp update_table(dids) do
    # We could do a full replace or a merge.
    # For simplicity and atomicity, we can insert all and then delete ones that are not in the list?
    # Or just clear and re-insert. Since it's a cache, clearing briefly is okay,
    # but concurrent reads might miss.
    # Better approach: Insert new ones, delete old ones.

    # Actually, :ets.insert overwrites.
    # To remove stale ones, we'd need to know which ones to remove.
    # Let's just use :ets.delete_all_objects first for now.
    # It's a firehose filter, if we miss a few ms of posts it's acceptable.

    :ets.delete_all_objects(@table_name)
    objects = Enum.map(dids, &{&1})
    :ets.insert(@table_name, objects)

    # Verify contents
    count = :ets.info(@table_name, :size)
    Logger.info("SourceCache updated. Table size: #{count}")
    Logger.info("Sample cached DIDs: #{inspect(Enum.take(dids, 5))}")
  end

  defp parse_feedbrainer_url(nil), do: nil
  defp parse_feedbrainer_url(_), do: nil # Placeholder if we needed to derive from DB URL
end
