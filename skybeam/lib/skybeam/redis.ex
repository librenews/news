defmodule Skybeam.Redis do
  @moduledoc """
  Redis connection for pushing firehose events to Rails.
  """
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Push a message to the firehose queue.
  Returns :ok on success, {:error, reason} on failure.
  """
  def push_to_queue(message) when is_binary(message) do
    GenServer.call(__MODULE__, {:push, message})
  end

  @impl true
  def init(_) do
    redis_url = System.get_env("REDIS_URL") || "redis://localhost:6379/0"
    
    case Redix.start_link(redis_url, name: :redix) do
      {:ok, conn} ->
        Logger.info("Connected to Redis at #{redis_url}")
        {:ok, conn}
      
      {:error, reason} ->
        Logger.error("Failed to connect to Redis: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:push, message}, _from, conn) do
    # Push to a Redis list - Rails will BRPOP (blocking pop)
    # LPUSH + BRPOP = FIFO queue with instant delivery
    case Redix.command(conn, ["LPUSH", "bluesky:firehose", message]) do
      {:ok, _queue_length} ->
        {:reply, :ok, conn}
      
      {:error, reason} = error ->
        Logger.error("Failed to push to Redis queue: #{inspect(reason)}")
        {:reply, error, conn}
    end
  end
end
