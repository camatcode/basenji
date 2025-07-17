defmodule BasenjiWeb.ComicsControllerTest do
  use BasenjiWeb.ConnCase

  alias Basenji.Comics
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

  test "get_preview", %{conn: conn} do
    %{resource_location: loc} = build(:comic)
    {:ok, %{title: nil, page_count: -1, format: nil} = comic} = Comics.create_comic(%{resource_location: loc})

    %{status: 200, resp_body: body} =
      get(conn, ~p"/api/comics/#{comic.id}/preview", %{})

    assert body
    %{failure: 0} = TestHelper.drain_queue(:comic)
  end
end
