defmodule BasenjiWeb.API.Utils do
  @moduledoc false

  import Ecto.Changeset
  import Phoenix.Controller
  import Plug.Conn

  require Logger

  def atomize(m) when is_map(m) do
    m
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  def validate_request_params(params, types, required_params) do
    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required(required_params)
    |> apply_action(:validate)
  end

  def safe_to_int(str) when is_bitstring(str) do
    result = str |> String.trim() |> String.to_integer()
    {:ok, result}
  rescue
    _ -> {:error, :not_int}
  end

  def bad_request_handler(conn, error) do
    case error do
      {:error, msg} when is_binary(msg) or is_atom(msg) ->
        conn
        |> put_status(400)
        |> json(%{error: msg})

      {:error, changeset} when is_map(changeset) ->
        %{errors: errors} = changeset
        Logger.error(inspect(errors))

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, inspect(errors))

      error ->
        Logger.error("Something went wrong, got: " <> inspect(error))

        conn
    end
  end
end
