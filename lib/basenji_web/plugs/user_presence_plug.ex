defmodule BasenjiWeb.Plugs.UserPresencePlug do
  @moduledoc false

  import Plug.Conn

  alias Basenji.UserPresenceTracker

  def init(opts), do: opts

  def call(conn, _opts) do
    if live_request?(conn) do
      UserPresenceTracker.track_presence(self())
    end

    conn
  end

  defp live_request?(conn) do
    conn.private[:phoenix_live_view] != nil or get_req_header(conn, "upgrade") == ["websocket"]
  end
end
