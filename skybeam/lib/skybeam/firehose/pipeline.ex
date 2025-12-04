defmodule Skybeam.Firehose.Pipeline do
  use Broadway
  require Logger
  alias Skybeam.SourceCache

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Skybeam.Firehose.Producer, []},
        concurrency: 1,
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [
          concurrency: 10
        ]
      ],
      batchers: [
        default: [
          batch_size: 10,
          batch_timeout: 1000,
          concurrency: 5
        ]
      ]
    )
  end

  def transform(event, _opts) do
    %Broadway.Message{
      data: event,
      acknowledger: {Broadway.NoopAcknowledger, nil, nil}
    }
  end

  @impl true
  def handle_message(_processor, message, _context) do
    # Decode JSON in parallel across Broadway processors
    case Jason.decode(message.data) do
      {:ok, %{"commit" => %{"collection" => collection}, "did" => did} = event} when collection in ["app.bsky.feed.post", "app.bsky.feed.repost"] ->
        # Check if this DID is in our source cache
        if SourceCache.exists?(did) do
          Logger.info("Relevant post found from DID: #{did}")
          # Update message data with decoded event
          %{message | data: event}
        else
          # Drop messages from DIDs we don't care about
          Broadway.Message.failed(message, :not_relevant)
        end

      {:ok, other_event} ->
        # Not a post or missing required fields
        collection = get_in(other_event, ["commit", "collection"])
        did = Map.get(other_event, "did", "unknown")
        Logger.info("Filtered out (wrong collection): collection=#{inspect(collection)}, did=#{did}")
        Broadway.Message.failed(message, :wrong_collection)

      {:error, reason} ->
        Logger.warning("Failed to decode Jetstream message: #{inspect(reason)}")
        Broadway.Message.failed(message, :invalid_json)
    end
  end

  @impl true
  def handle_batch(_batcher, messages, _batch_info, _context) do
    # Push each relevant message to Redis for Rails to consume
    Enum.each(messages, fn message ->
      # Re-encode the event as JSON for Redis
      case Jason.encode(message.data) do
        {:ok, json} ->
          case Skybeam.Redis.push_to_queue(json) do
            :ok ->
              Logger.debug("Pushed message to Redis queue")

            {:error, reason} ->
              Logger.error("Failed to push to Redis: #{inspect(reason)}")
          end

        {:error, reason} ->
          Logger.error("Failed to encode message for Redis: #{inspect(reason)}")
      end
    end)

    if length(messages) > 0 do
      Logger.info("Pushed #{length(messages)} messages to Redis queue")
    end

    messages
  end
end
