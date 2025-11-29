defmodule SkybeamWeb.Router do
  use SkybeamWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SkybeamWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SkybeamWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Health check endpoints (no authentication required)
  scope "/", SkybeamWeb do
    pipe_through :api

    get "/health", HealthController, :health
    get "/health/ready", HealthController, :ready
    get "/health/live", HealthController, :live
  end

  # Debug endpoints
  scope "/debug", SkybeamWeb do
    pipe_through :api

    get "/cache/check", DebugController, :check_cache
    post "/cache/refresh", DebugController, :refresh_cache
  end

  # Other scopes may use custom stacks.
  # scope "/api", SkybeamWeb do
  #   pipe_through :api
  # end
end
