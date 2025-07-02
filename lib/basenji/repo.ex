defmodule Basenji.Repo do
  use Ecto.Repo,
    otp_app: :basenji,
    adapter: Ecto.Adapters.Postgres

  require Logger

  defoverridable one: 1, one: 2, all: 1, all: 2

  @impl true
  def one(query, opts \\ []) do
    super(query, opts)
  rescue
    err in Ecto.Query.CastError ->
      if err.type == Ecto.UUID do
        Logger.warning("Received invalid UUID #{err.value} in query #{inspect(query)}")
        nil
      else
        reraise err, __STACKTRACE__
      end
  end

  @impl true
  def all(query, opts \\ []) do
    super(query, opts)
  rescue
    err in Ecto.Query.CastError ->
      if err.type == Ecto.UUID do
        Logger.warning("Received invalid UUID #{err.value} in query #{inspect(query)}")
        nil
      else
        reraise err, __STACKTRACE__
      end
  end
end
