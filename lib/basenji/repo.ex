defmodule Basenji.Repo do
  use Ecto.Repo,
    otp_app: :basenji,
    adapter: Ecto.Adapters.Postgres
end
