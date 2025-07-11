defmodule BasenjiWeb.GraphQL.ComicsSchemaTest do
  use BasenjiWeb.ConnCase

  alias BasenjiWeb.GraphQL.ComicsSchema

  @moduletag :capture_log

  doctest ComicsSchema

  @api_path "/api/graphql"

  test "list comics", %{conn: conn} do
    query_name = "listComics"
    comic_ids = insert_list(100, :comic) |> Enum.map(& &1.id)

    query = """
    query{ #{query_name} {
      id
    }}
    """

    %{"data" => %{^query_name => found}} =
      conn
      |> post(@api_path, %{query: query})
      |> json_response(200)

    assert Enum.count(found) == Enum.count(comic_ids)

    found
    |> Enum.each(fn found_comic ->
      assert Enum.member?(comic_ids, found_comic["id"])
    end)
  end

  test "get comic", %{conn: conn} do
  end
end
