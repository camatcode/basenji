defmodule BasenjiWeb.GraphQL.ComicsSchemaTest do
  use BasenjiWeb.ConnCase

  import TestHelper.GraphQL

  alias BasenjiWeb.GraphQL.ComicsSchema

  @moduletag :capture_log

  doctest ComicsSchema

  @api_path "/api/graphql"

  test "get comic", %{conn: conn} do
    comics = insert_list(10, :comic)
    query_name = "comic"

    Enum.each(comics, fn %{id: comic_id} ->
      query = build_query(query_name, "id: \"#{comic_id}\"")
      response = execute_query(@api_path, conn, query)
      assert_single_comic(response, comic_id, query_name)
    end)
  end

  describe "list" do
    test "simple list", %{conn: conn} do
      comic_ids = insert_list(100, :comic) |> Enum.map(& &1.id)

      query = build_query("comics")
      %{"data" => %{"comics" => found}} = execute_query(@api_path, conn, query)

      assert Enum.count(found) == Enum.count(comic_ids)

      found
      |> Enum.each(fn found_comic ->
        assert Enum.member?(comic_ids, found_comic["id"])
      end)
    end

    test "offset/limit", %{conn: conn} do
      insert_list(100, :comic)

      0..9
      |> Enum.reduce(nil, fn page_idx, offset ->
        query = build_query("comics", "limit: 10, offset: #{offset || 0}")
        %{"data" => %{"comics" => found}} = execute_query(@api_path, conn, query)

        assert Enum.count(found) == 10
        (page_idx + 1) * 10
      end)
    end

    test "search by", %{conn: conn} do
      comics = insert_list(10, :comic)

      search_fields = [
        {"title", fn comic -> comic.title end},
        {"author", fn comic -> comic.author end},
        {"resource_location", fn comic -> comic.resource_location end}
      ]

      Enum.each(comics, fn comic ->
        comic_id = comic.id

        # Test individual field searches
        Enum.each(search_fields, fn {field, value_fn} ->
          query = build_search_query(field, value_fn.(comic))
          response = execute_query(@api_path, conn, query)
          assert_exact_comic_match(response, comic_id)
        end)

        # Test format search (special case with uppercase)
        format_query = build_query("comics", "format: #{comic.format |> Atom.to_string() |> String.upcase()}")
        format_response = execute_query(@api_path, conn, format_query)
        assert_comic_in_response(format_response, comic_id)

        # Test released_year search
        year_query = build_search_query("released_year", comic.released_year)
        year_response = execute_query(@api_path, conn, year_query)
        assert_comic_in_response(year_response, comic_id)
      end)
    end

    test "search by time", %{conn: conn} do
      insert_list(10, :comic)
      :timer.sleep(1000)
      dt = DateTime.utc_now() |> DateTime.to_iso8601()
      :timer.sleep(1000)
      comic_id = insert(:comic).id

      # Test inserted_after
      after_query = build_search_query("inserted_after", dt)
      after_response = execute_query(@api_path, conn, after_query)
      assert_exact_comic_match(after_response, comic_id)

      # Test insertedBefore
      before_query = build_search_query("insertedBefore", dt)
      %{"data" => %{"comics" => found}} = execute_query(@api_path, conn, before_query)

      refute Enum.empty?(found)
      refute Enum.member?(found, %{"id" => comic_id})
    end

    test "generic search", %{conn: conn} do
      %{id: a_id} =
        insert(:comic,
          title: "Baz and Peace",
          author: "Arthur Smith",
          description: "A thrilling murder mystery"
        )

      %{id: b_id} =
        insert(:comic,
          title: "Of foo and bar, or On The 25-fold Path",
          author: "Jane Smith",
          description: "Her best romance novel"
        )

      %{id: c_id} =
        insert(:comic,
          title: "Potion-seller's guide to the galaxy",
          author: "Sam Major",
          description: "25 chapters of dense reading"
        )

      search_cases = [
        {"and", [a_id, b_id]},
        {"or", [b_id, c_id]},
        {"25", [b_id, c_id]}
      ]

      Enum.each(search_cases, fn {search_term, expected_ids} ->
        query = build_query("comics", "order_by: TITLE, search: \"#{search_term}\"")
        %{"data" => %{"comics" => found}} = execute_query(@api_path, conn, query)

        found_ids = Enum.map(found, & &1["id"])
        assert found_ids == expected_ids
      end)
    end
  end
end
