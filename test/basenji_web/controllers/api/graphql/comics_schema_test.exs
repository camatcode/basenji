defmodule BasenjiWeb.GraphQL.ComicsSchemaTest do
  use BasenjiWeb.ConnCase

  import TestHelper.GraphQL

  alias Basenji.Comics
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

  test "get comic with invalid id", %{conn: conn} do
    query = build_query("comic", "id: \"#{Ecto.UUID.generate()}\"")
    %{"errors" => [%{"message" => "Not found"}]} = execute_query(@api_path, conn, query)
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
      insert_list(50, :comic)

      query = build_query("comics", "limit: 10, offset: 0")
      %{"data" => %{"comics" => first_page}} = execute_query(@api_path, conn, query)
      assert Enum.count(first_page) == 10
      first_page_ids = Enum.map(first_page, & &1["id"])

      query = build_query("comics", "limit: 10, offset: 10")
      %{"data" => %{"comics" => second_page}} = execute_query(@api_path, conn, query)
      assert Enum.count(second_page) == 10
      second_page_ids = Enum.map(second_page, & &1["id"])

      refute Enum.any?(first_page_ids, &Enum.member?(second_page_ids, &1))
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

        format_query = build_query("comics", "format: #{comic.format |> Atom.to_string() |> String.upcase()}")
        format_response = execute_query(@api_path, conn, format_query)
        assert_comic_in_response(format_response, comic_id)

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

      after_query = build_search_query("inserted_after", dt)
      after_response = execute_query(@api_path, conn, after_query)
      assert_exact_comic_match(after_response, comic_id)

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

  describe "mutations" do
    test "create comic", %{conn: conn} do
      %{resource_location: loc, released_year: r_year} = build(:comic)

      input = %{
        title: Faker.Lorem.sentence(),
        description: Faker.Lorem.paragraph(2),
        author: Faker.Person.name(),
        resourceLocation: loc,
        releasedYear: r_year
      }

      mutation = """
      mutation {
        createComic(input: {
          title: "#{input.title}"
          description: "#{input.description}"
          author: "#{input.author}"
          resourceLocation: "#{input.resourceLocation}"
          releasedYear: #{input.releasedYear}
        }) {
          id
          title
          description
          author
          resourceLocation
          releasedYear
        }
      }
      """

      %{"data" => %{"createComic" => comic}} = execute_query(@api_path, conn, mutation)

      assert comic["title"] == input.title
      assert comic["description"] == input.description
      assert comic["author"] == input.author
      assert comic["resourceLocation"] == input.resourceLocation
      assert comic["releasedYear"] == input.releasedYear
      assert comic["id"]
    end

    test "create comic with invalid data", %{conn: conn} do
      mutation = """
      mutation {
        createComic(input: {
          resourceLocation: "/nonexistent/path.cbz"
        }) {
          id
        }
      }
      """

      %{"errors" => [%{"message" => message}]} = execute_query(@api_path, conn, mutation)
      assert String.contains?(message, "resource_location does not exist")
    end

    test "update comic", %{conn: conn} do
      comic = insert(:comic)

      updated_title = Faker.Lorem.sentence()
      updated_author = Faker.Person.name()
      updated_description = Faker.Lorem.paragraph(2)
      updated_year = 2023

      mutation = """
      mutation {
        updateComic(id: "#{comic.id}", input: {
          title: "#{updated_title}"
          author: "#{updated_author}"
          description: "#{updated_description}"
          releasedYear: #{updated_year}
        }) {
          id
          title
          author
          description
          releasedYear
          resourceLocation
        }
      }
      """

      %{"data" => %{"updateComic" => updated}} = execute_query(@api_path, conn, mutation)

      assert updated["id"] == comic.id
      assert updated["title"] == updated_title
      assert updated["author"] == updated_author
      assert updated["description"] == updated_description
      assert updated["releasedYear"] == updated_year
      assert updated["resourceLocation"] == comic.resource_location
    end

    test "update comic with invalid id", %{conn: conn} do
      mutation = """
      mutation {
        updateComic(id: "#{Ecto.UUID.generate()}", input: {
          title: "New Title"
        }) {
          id
        }
      }
      """

      %{"errors" => [%{"message" => "Not found"}]} = execute_query(@api_path, conn, mutation)
    end

    test "delete comic", %{conn: conn} do
      comic = insert(:comic)

      mutation = """
      mutation {
        deleteComic(id: "#{comic.id}")
      }
      """

      %{"data" => %{"deleteComic" => true}} = execute_query(@api_path, conn, mutation)

      {:error, :not_found} = Comics.get_comic(comic.id)
    end

    test "delete comic with invalid id", %{conn: conn} do
      mutation = """
      mutation {
        deleteComic(id: "#{Ecto.UUID.generate()}")
      }
      """

      %{"errors" => [%{"message" => "Not found"}]} = execute_query(@api_path, conn, mutation)
    end
  end
end
