defmodule Skybeam.Repo do
  use Ecto.Repo,
    otp_app: :skybeam,
    adapter: Ecto.Adapters.Postgres
end
