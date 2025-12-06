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
      {:ok, %{"commit" => %{"collection" => collection}} = event} when collection in ["app.bsky.feed.post", "app.bsky.feed.repost"] ->
        # Check if the post has any links (facets, embeds, or is a repost)
        if has_link?(event) do
          # Logger.debug("Link found in post from DID: #{event["did"]}")
          %{message | data: event}
        else
          # Drop messages without links
          Broadway.Message.failed(message, :no_link)
        end

      {:ok, other_event} ->
        # Not a post or missing required fields
        collection = get_in(other_event, ["commit", "collection"])
        did = Map.get(other_event, "did", "unknown")
        # Logger.debug("Filtered out (wrong collection): collection=#{inspect(collection)}, did=#{did}")
        Broadway.Message.failed(message, :wrong_collection)

      {:error, reason} ->
        Logger.warning("Failed to decode Jetstream message: #{inspect(reason)}")
        Broadway.Message.failed(message, :invalid_json)
    end
  end

  defp has_link?(%{"commit" => %{"record" => record, "collection" => "app.bsky.feed.post"}}) do
    has_link_facet?(record) || has_external_embed?(record) || has_record_embed?(record)
  end

  defp has_link?(%{"commit" => %{"collection" => "app.bsky.feed.repost"}}) do
    true # All reposts are treated as having a "link" to the original content
  end

  defp has_link?(_), do: false

  defp has_link_facet?(record) do
    facets = Map.get(record, "facets", []) || []
    Enum.any?(facets, fn facet ->
      features = Map.get(facet, "features", []) || []
      Enum.any?(features, fn feature ->
        feature["$type"] == "app.bsky.richtext.facet#link"
      end)
    end)
  end

  defp has_external_embed?(record) do
    case Map.get(record, "embed") do
      %{"$type" => "app.bsky.embed.external"} -> true
      _ -> false
    end
  end

  defp has_record_embed?(record) do
    case Map.get(record, "embed") do
      %{"$type" => "app.bsky.embed.record"} -> true
      %{"$type" => "app.bsky.embed.recordWithMedia"} -> true
      _ -> false
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
