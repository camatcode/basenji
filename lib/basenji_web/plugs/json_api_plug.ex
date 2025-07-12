defmodule BasenjiWeb.Plugs.JSONAPIPlug do
  @moduledoc false
  import Plug.Conn

  alias JSONAPIPlug.Exceptions.InvalidDocument
  alias Plug.Conn.Status

  def init(opts), do: opts

  def call(conn, opts) do
    JSONAPIPlug.Plug.call(conn, JSONAPIPlug.Plug.init(opts))
  rescue
    # handles a bug in json_api_plug where they mistakenly use :unsupported_content_type
    # instead of :unsupported_media_type
    e in FunctionClauseError ->
      if e.module == Status and e.function == :code and e.arity == 1 and
           String.contains?(Exception.message(e), "no function clause matching in Plug.Conn.Status.code/1") do
        send_415_response(conn)
      else
        reraise e, __STACKTRACE__
      end

    # Handle JSONAPIPlug validation errors as 400 Bad Request
    e in InvalidDocument ->
      send_400_response(conn, "Invalid JSON:API document: #{Exception.message(e)}")

    # Handle Ecto cast errors (like invalid UUIDs) as 400 Bad Request
    e in Ecto.Query.CastError ->
      send_400_response(conn, "Invalid data format: #{Exception.message(e)}")

    other_error ->
      reraise other_error, __STACKTRACE__
  end

  defp send_415_response(conn) do
    error_response = %{
      errors: [
        %{
          status: "415",
          title: "Unsupported Media Type",
          detail: "Content-Type header must be 'application/vnd.api+json' for JSON:API requests",
          source: %{
            header: "Content-Type"
          }
        }
      ]
    }

    conn
    |> put_status(415)
    |> put_resp_content_type("application/vnd.api+json")
    |> send_resp(415, Jason.encode!(error_response))
    |> halt()
  end

  defp send_400_response(conn, detail) do
    error_response = %{
      errors: [
        %{
          status: "400",
          title: "Bad Request",
          detail: detail
        }
      ]
    }

    conn
    |> put_status(400)
    |> put_resp_content_type("application/vnd.api+json")
    |> send_resp(400, Jason.encode!(error_response))
    |> halt()
  end
end
