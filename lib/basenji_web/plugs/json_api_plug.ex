defmodule BasenjiWeb.Plugs.JSONAPIPlug do
  @moduledoc false
  import Plug.Conn

  alias Plug.Conn.Status

  def init(opts), do: opts

  def call(conn, opts) do
    JSONAPIPlug.Plug.call(conn, JSONAPIPlug.Plug.init(opts))
  rescue
    e in FunctionClauseError ->
      if e.module == Status and e.function == :code and e.arity == 1 and
           String.contains?(Exception.message(e), "no function clause matching in Plug.Conn.Status.code/1") do
        send_415_response(conn)
      else
        reraise e, __STACKTRACE__
      end

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
end
