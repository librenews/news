defmodule SkybeamWeb.HealthController do
  use SkybeamWeb, :controller

  def health(conn, _params) do
    json(conn, %{status: "healthy", service: "skybeam"})
  end

  def ready(conn, _params) do
    # TODO: Add database connection check
    json(conn, %{status: "ready"})
  end

  def live(conn, _params) do
    json(conn, %{status: "alive"})
  end
end
