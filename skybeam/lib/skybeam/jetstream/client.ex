defmodule Skybeam.Jetstream.Client do
  use WebSockex
  require Logger

  @url "wss://jetstream2.us-east.bsky.network/subscribe"

  def start_link(_opts) do
    # Filter for posts only to reduce bandwidth
    query = URI.encode_query(%{"wantedCollections" => "app.bsky.feed.post"})
    url = "#{@url}?#{query}"
    
    Logger.info("Connecting to Jetstream at #{url}")
    WebSockex.start_link(url, __MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Connected to Jetstream")
    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("Disconnected from Jetstream: #{inspect(reason)}")
    {:reconnect, state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    # Pass raw JSON string to Producer - decoding happens in Broadway pipeline
    Skybeam.Firehose.Producer.notify_events([msg])
    {:ok, state}
  end
end
