defmodule BasenjiWeb.ComicsControllerTest do
  use BasenjiWeb.ConnCase

  alias Basenji.Comics
  alias BasenjiWeb.ComicsController

  @moduletag :capture_log

  doctest ComicsController

  test "create comic", %{conn: conn} do
    comic = build(:comic) |> Map.from_struct()
    conn = post(conn, ~p"/api/comics", comic)
    assert %{"data" => comic} = json_response(conn, 200)
    assert valid_comic?(comic)
  end

  test "lists comics", %{conn: conn} do
    insert_list(100, :comic)
    conn = get(conn, ~p"/api/comics", %{})

    assert %{"data" => comics} = json_response(conn, 200)
    refute Enum.empty?(comics)

    comics
    |> Enum.each(fn comic ->
      assert valid_comic?(comic)
    end)
  end

  test "get comic", %{conn: conn} do
    comic = insert(:comic)
    conn = get(conn, ~p"/api/comics/#{comic.id}", %{})

    assert %{"data" => comic} = json_response(conn, 200)
    assert valid_comic?(comic)
  end

  test "update comic", %{conn: conn} do
    comic = insert(:comic) |> Map.from_struct()
    changes = build(:comic) |> Map.from_struct()

    conn = patch(conn, ~p"/api/comics/#{comic.id}", changes)

    assert %{"data" => updated} = json_response(conn, 200)
    assert valid_comic?(updated)
    # changed
    assert updated["author"] == changes.author
    assert updated["description"] == changes.description
    assert updated["released_year"] == changes.released_year
    assert updated["title"] == changes.title

    # unchanged
    assert updated["format"] == "#{comic.format}"
    assert updated["id"] == comic.id
    assert updated["page_count"] == comic.page_count
  end

  test "delete comic", %{conn: conn} do
    comic = insert(:comic)
    conn = delete(conn, ~p"/api/comics/#{comic.id}", %{})

    assert %{"data" => deleted} = json_response(conn, 200)
    assert deleted["id"] == comic.id

    {:error, :not_found} = Comics.get_comic(comic.id)
  end

  defp valid_comic?(comic_json) do
    assert comic_json["id"]
    assert comic_json["author"]
    assert comic_json["description"]
    assert comic_json["format"]
    assert comic_json["page_count"]
    assert comic_json["inserted_at"]
    assert comic_json["page_count"]
    assert comic_json["released_year"]
    assert comic_json["resource_location"]
    assert comic_json["title"]
    assert comic_json["updated_at"]
    true
  end
end
