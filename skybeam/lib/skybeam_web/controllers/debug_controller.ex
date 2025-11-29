defmodule SkybeamWeb.DebugController do
  use SkybeamWeb, :controller
  require Logger
  alias Skybeam.SourceCache

  def check_cache(conn, %{"did" => did}) do
    exists = SourceCache.exists?(did)

    # Get all cached DIDs
    all_dids = :ets.tab2list(:source_dids) |> Enum.map(fn {d} -> d end)

    json(conn, %{
      did: did,
      in_cache: exists,
      total_cached: length(all_dids),
      all_dids: all_dids
    })
  end

  def refresh_cache(conn, _params) do
    SourceCache.refresh()
    json(conn, %{status: "ok", message: "Cache refresh triggered"})
  end
end
