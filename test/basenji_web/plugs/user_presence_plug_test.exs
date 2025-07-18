defmodule BasenjiWeb.Plugs.UserPresencePlugTest do
  use BasenjiWeb.ConnCase

  alias Basenji.UserPresenceTracker
  alias BasenjiWeb.Plugs.UserPresencePlug

  test "plug tracks LiveView requests", %{conn: conn} do
    refute UserPresenceTracker.anyone_browsing?()

    conn
    |> put_private(:phoenix_live_view, true)
    |> UserPresencePlug.call([])

    assert UserPresenceTracker.anyone_browsing?()
  end

  test "plug ignores non-LiveView requests", %{conn: conn} do
    refute UserPresenceTracker.anyone_browsing?()

    _conn = UserPresencePlug.call(conn, [])

    refute UserPresenceTracker.anyone_browsing?()
  end
end
