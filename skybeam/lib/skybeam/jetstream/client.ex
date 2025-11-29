defmodule Skybeam.Jetstream.Client do
  use WebSockex
  require Logger

  @url "wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post"

  def start_link(_opts) do
    # Add headers that might be expected by Jetstream
    extra_headers = [
      {"User-Agent", "Skybeam/1.0"},
      {"Accept", "*/*"}
    ]
    
    opts = [
      extra_headers: extra_headers,
      async: true
    ]
    
    Logger.info("Connecting to Jetstream at #{@url}")
    WebSockex.start_link(@url, __MODULE__, %{}, [name: __MODULE__] ++ opts)
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
    Logger.info("Received frame: #{String.slice(msg, 0, 100)}")
    # Pass raw JSON string to Producer - decoding happens in Broadway pipeline
    Skybeam.Firehose.Producer.notify_events([msg])
    {:ok, state}
  end

  @impl true
  def handle_frame({:ping, _}, state) do
    {:reply, :pong, state}
  end

  @impl true
  def handle_frame({:pong, _}, state) do
    {:ok, state}
  end

  @impl true
  def handle_frame({:binary, _msg}, state) do
    {:ok, state}
  end

  @impl true
  def handle_frame(_frame, state) do
    {:ok, state}
  end
end
