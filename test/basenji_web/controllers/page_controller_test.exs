defmodule BasenjiWeb.PageControllerTest do
  use BasenjiWeb.ConnCase

  test "GET /", %{conn: conn} do
    _conn = get(conn, ~p"/")
  end
end
