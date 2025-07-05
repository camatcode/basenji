defmodule BasenjiWeb.ComicsControllerTest do
  use BasenjiWeb.ConnCase

  alias BasenjiWeb.ComicsController

  @moduletag :capture_log

  doctest ComicsController

  test "get_page", %{conn: conn} do
    comic = insert(:comic)

    1..comic.page_count
    |> Enum.each(fn page ->
      conn = get(conn, ~p"/api/comics/#{comic.id}/page/#{page}", %{})
      assert conn.status == 200
      assert conn.resp_body
    end)
  end
end
