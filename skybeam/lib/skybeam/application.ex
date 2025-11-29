defmodule Skybeam.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SkybeamWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:skybeam, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Skybeam.PubSub},
      Skybeam.Repo,
      # Start a worker by calling: Skybeam.Worker.start_link(arg)
      # {Skybeam.Worker, arg},
      # Start to serve requests, typically the last entry
      SkybeamWeb.Endpoint,
      Skybeam.Redis,
      Skybeam.SourceCache,
      # Skybeam.Firehose.Producer is started by the Pipeline (Broadway)
      Skybeam.Firehose.Pipeline,
      Skybeam.Jetstream.Client
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Skybeam.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SkybeamWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
