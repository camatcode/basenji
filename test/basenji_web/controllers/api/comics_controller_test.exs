defmodule BasenjiWeb.ComicsControllerTest do
  use BasenjiWeb.ConnCase

  alias BasenjiWeb.ComicsController

  @moduletag :capture_log

  doctest ComicsController

  test "lists comics", %{conn: conn} do
    insert_list(100, :comic)
    conn = get(conn, ~p"/api/comics", %{})

    assert %{"data" => comics} = json_response(conn, 200)
    refute Enum.empty?(comics)

    comics
    |> Enum.each(fn comic ->
      assert comic["id"]
      assert comic["author"]
      assert comic["description"]
      assert comic["format"]
      assert comic["page_count"]
      assert comic["inserted_at"]
      assert comic["page_count"]
      assert comic["released_year"]
      assert comic["resource_location"]
      assert comic["title"]
      assert comic["updated_at"]
    end)
  end
end
