defmodule BasenjiWeb.GraphQL.ComicsSchemaTest do
  use BasenjiWeb.ConnCase

  alias BasenjiWeb.GraphQL.ComicsSchema

  @moduletag :capture_log

  doctest ComicsSchema

  @api_path "/api/graphql"

  describe "list" do
    test "simple list", %{conn: conn} do
      comic_ids = insert_list(100, :comic) |> Enum.map(& &1.id)
      query_name = "comics"

      query = """
      {
        #{query_name} {
          id
        }
      }
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

    test "offset/limit", %{conn: conn} do
      insert_list(100, :comic)
      query_name = "comics"

      0..9
      |> Enum.reduce(nil, fn page_idx, offset ->
        query = """
        {
          #{query_name}(limit: 10, offset: #{offset || 0}) {
            id
          }
        }
        """

        %{"data" => %{^query_name => found}} =
          conn
          |> post(@api_path, %{query: query})
          |> json_response(200)

        assert Enum.count(found) == 10
        (page_idx + 1) * 10
      end)
    end

    test "search by", %{conn: conn} do
      comics = insert_list(10, :comic)

      Enum.each(comics, fn comic ->
        query_name = "comics"
        comic_id = comic.id

        query = """
        {
          #{query_name}(title: "#{comic.title}") {
            id
          }
        }
        """

        %{"data" => %{^query_name => [%{"id" => ^comic_id}]}} =
          conn
          |> post(@api_path, %{query: query})
          |> json_response(200)

        query = """
        {
          #{query_name}(author: "#{comic.author}") {
            id
          }
        }
        """

        %{"data" => %{^query_name => [%{"id" => ^comic_id}]}} =
          conn
          |> post(@api_path, %{query: query})
          |> json_response(200)

        query = """
        {
          #{query_name}(resource_location: "#{comic.resource_location}") {
            id
          }
        }
        """

        %{"data" => %{^query_name => [%{"id" => ^comic_id}]}} =
          conn
          |> post(@api_path, %{query: query})
          |> json_response(200)

        query = """
        {
          #{query_name}(format: #{comic.format |> Atom.to_string() |> String.upcase()}) {
            id
          }
        }
        """

        %{"data" => %{^query_name => found}} =
          conn
          |> post(@api_path, %{query: query})
          |> json_response(200)

        assert Enum.member?(found, %{"id" => comic_id})

        query = """
        {
          #{query_name}(released_year: #{comic.released_year}) {
            id
          }
        }
        """

        %{"data" => %{^query_name => found}} =
          conn
          |> post(@api_path, %{query: query})
          |> json_response(200)

        assert Enum.member?(found, %{"id" => comic_id})
      end)
    end

    test "search by time", %{conn: conn} do
      insert_list(10, :comic)
      :timer.sleep(1000)
      dt = DateTime.utc_now() |> DateTime.to_iso8601()
      :timer.sleep(1000)
      comic_id = insert(:comic).id
      query_name = "comics"

      query = """
      {
        #{query_name}(inserted_after: "#{dt}") {
          id
        }
      }
      """

      %{"data" => %{^query_name => [%{"id" => ^comic_id}]}} =
        conn
        |> post(@api_path, %{query: query})
        |> json_response(200)

      query = """
      {
        #{query_name}(insertedBefore: "#{dt}") {
          id
        }
      }
      """

      %{"data" => %{^query_name => found}} =
        conn
        |> post(@api_path, %{query: query})
        |> json_response(200)

      refute Enum.empty?(found)
      refute Enum.member?(found, %{"id" => comic_id})

      #  updated before / after
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

      query_name = "comics"

      query = """
      {
        #{query_name}(order_by: TITLE, search: "and") {
          id
        }
      }
      """

      %{
        "data" => %{
          ^query_name => [
            %{"id" => ^a_id},
            %{"id" => ^b_id}
          ]
        }
      } =
        conn
        |> post(@api_path, %{query: query})
        |> json_response(200)

      query = """
      {
        #{query_name}(order_by: TITLE, search: "or") {
          id
        }
      }
      """

      %{
        "data" => %{
          ^query_name => [
            %{"id" => ^b_id},
            %{"id" => ^c_id}
          ]
        }
      } =
        conn
        |> post(@api_path, %{query: query})
        |> json_response(200)

      query = """
      {
        #{query_name}(order_by: TITLE, search: "25") {
          id
        }
      }
      """

      %{
        "data" => %{
          ^query_name => [
            %{"id" => ^b_id},
            %{"id" => ^c_id}
          ]
        }
      } =
        conn
        |> post(@api_path, %{query: query})
        |> json_response(200)
    end
  end

  test "get comic", %{conn: _conn} do
  end
end
