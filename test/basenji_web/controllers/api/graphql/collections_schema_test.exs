defmodule BasenjiWeb.GraphQL.CollectionsSchemaTest do
  use BasenjiWeb.ConnCase

  import TestHelper.GraphQL

  alias Basenji.Collections
  alias BasenjiWeb.GraphQL.CollectionsSchema

  @moduletag :capture_log

  doctest CollectionsSchema

  @api_path "/api/graphql"

  test "get collection", %{conn: conn} do
    collections = insert_list(10, :collection)
    query_name = "collection"

    Enum.each(collections, fn %{id: collection_id} ->
      query = build_query(query_name, "id: \"#{collection_id}\"")
      response = execute_query(@api_path, conn, query)
      assert_single_object(response, collection_id, query_name)
    end)
  end

  test "get collection with invalid id", %{conn: conn} do
    query = build_query("collection", "id: \"#{Ecto.UUID.generate()}\"")
    %{"errors" => [%{"message" => "Not found"}]} = execute_query(@api_path, conn, query)
  end

  describe "list" do
    test "simple list", %{conn: conn} do
      collection_ids = insert_list(3, :collection) |> Enum.map(& &1.id)

      query = build_query("collections")
      %{"data" => %{"collections" => found}} = execute_query(@api_path, conn, query)

      found_ids = Enum.map(found, & &1["id"])

      Enum.each(collection_ids, fn collection_id ->
        assert Enum.member?(found_ids, collection_id)
      end)
    end

    test "offset/limit", %{conn: conn} do
      insert_list(25, :collection)

      query = build_query("collections", "limit: 5, offset: 0")
      %{"data" => %{"collections" => first_page}} = execute_query(@api_path, conn, query)
      assert Enum.count(first_page) == 5
      first_page_ids = Enum.map(first_page, & &1["id"])

      query = build_query("collections", "limit: 5, offset: 5")
      %{"data" => %{"collections" => second_page}} = execute_query(@api_path, conn, query)
      assert Enum.count(second_page) == 5
      second_page_ids = Enum.map(second_page, & &1["id"])

      refute Enum.any?(first_page_ids, &Enum.member?(second_page_ids, &1))
    end

    test "search by", %{conn: conn} do
      collections = insert_list(3, :collection)

      search_fields = [
        {"title", fn collection -> collection.title end},
        {"description", fn collection -> collection.description end}
      ]

      Enum.each(collections, fn collection ->
        collection_id = collection.id

        Enum.each(search_fields, fn {field, value_fn} ->
          query = build_search_query_for("collections", field, value_fn.(collection))
          response = execute_query(@api_path, conn, query)
          assert_exact_collection_match(response, collection_id)
        end)
      end)
    end

    test "generic search", %{conn: conn} do
      %{id: a_id} =
        insert(:collection,
          title: "My Favorite Comics",
          description: "A collection of my most loved stories"
        )

      %{id: b_id} =
        insert(:collection,
          title: "Horror Collection",
          description: "Scary and thrilling comics"
        )

      %{id: c_id} =
        insert(:collection,
          title: "Science Fiction",
          description: "Future worlds and technology"
        )

      search_cases = [
        {"Comics", [a_id]},
        {"collection", [a_id, b_id]},
        {"Fiction", [c_id]}
      ]

      Enum.each(search_cases, fn {search_term, expected_ids} ->
        query = build_query("collections", "search: \"#{search_term}\"")
        %{"data" => %{"collections" => found}} = execute_query(@api_path, conn, query)

        found_ids = Enum.map(found, & &1["id"])

        Enum.each(expected_ids, fn expected_id ->
          assert Enum.member?(found_ids, expected_id)
        end)
      end)
    end

    test "search by time", %{conn: conn} do
      insert_list(5, :collection)
      :timer.sleep(1000)
      dt = DateTime.utc_now() |> DateTime.to_iso8601()
      :timer.sleep(1000)
      collection_id = insert(:collection).id

      after_query = build_query("collections", "insertedAfter: \"#{dt}\"")
      %{"data" => %{"collections" => found_after}} = execute_query(@api_path, conn, after_query)

      found_after_ids = Enum.map(found_after, & &1["id"])
      assert Enum.member?(found_after_ids, collection_id)

      before_query = build_query("collections", "insertedBefore: \"#{dt}\"")
      %{"data" => %{"collections" => found_before}} = execute_query(@api_path, conn, before_query)

      refute Enum.empty?(found_before)
      found_before_ids = Enum.map(found_before, & &1["id"])
      refute Enum.member?(found_before_ids, collection_id)
    end
  end

  describe "mutations" do
    test "create collection", %{conn: conn} do
      input = %{
        title: Faker.Lorem.sentence(),
        description: Faker.Lorem.paragraph(2)
      }

      mutation = """
      mutation {
        createCollection(input: {
          title: "#{input.title}"
          description: "#{input.description}"
        }) {
          id
          title
          description
        }
      }
      """

      %{"data" => %{"createCollection" => collection}} = execute_query(@api_path, conn, mutation)

      assert collection["title"] == input.title
      assert collection["description"] == input.description
      assert collection["id"]
    end

    test "create collection with invalid data", %{conn: conn} do
      mutation = """
      mutation {
        createCollection(input: {
          description: "Missing required title"
        }) {
          id
        }
      }
      """

      %{"errors" => [%{"message" => message}]} = execute_query(@api_path, conn, mutation)
      assert String.contains?(message, "title")
    end

    test "update collection", %{conn: conn} do
      collection = insert(:collection)

      updated_title = Faker.Lorem.sentence()
      updated_description = Faker.Lorem.paragraph(2)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          title: "#{updated_title}"
          description: "#{updated_description}"
        }) {
          id
          title
          description
        }
      }
      """

      %{"data" => %{"updateCollection" => updated}} = execute_query(@api_path, conn, mutation)

      assert updated["id"] == collection.id
      assert updated["title"] == updated_title
      assert updated["description"] == updated_description
    end

    test "update collection with invalid id", %{conn: conn} do
      mutation = """
      mutation {
        updateCollection(id: "#{Ecto.UUID.generate()}", input: {
          title: "New Title"
        }) {
          id
        }
      }
      """

      %{"errors" => [%{"message" => "Not found"}]} = execute_query(@api_path, conn, mutation)
    end

    test "delete collection", %{conn: conn} do
      collection = insert(:collection)

      mutation = """
      mutation {
        deleteCollection(id: "#{collection.id}")
      }
      """

      %{"data" => %{"deleteCollection" => true}} = execute_query(@api_path, conn, mutation)

      {:error, :not_found} = Collections.get_collection(collection.id)
    end

    test "delete collection with invalid id", %{conn: conn} do
      mutation = """
      mutation {
        deleteCollection(id: "#{Ecto.UUID.generate()}")
      }
      """

      %{"errors" => [%{"message" => "Not found"}]} = execute_query(@api_path, conn, mutation)
    end
  end
end
