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

  describe "parent relationships" do
    test "retrieve collection with parent", %{conn: conn} do
      parent = insert(:collection)
      collection = insert(:collection, parent: parent)

      query = """
      {
        collection(id: "#{collection.id}") {
          id
          title
          parent {
            id
            title
          }
        }
      }
      """

      %{"data" => %{"collection" => result}} = execute_query(@api_path, conn, query)

      assert result["id"] == collection.id
      assert result["title"] == collection.title
      assert result["parent"]["id"] == parent.id
      assert result["parent"]["title"] == parent.title
    end

    test "list collections with parent", %{conn: conn} do
      parent = insert(:collection)
      child1 = insert(:collection, parent: parent)
      child2 = insert(:collection, parent: parent)
      insert(:collection)

      query = """
      {
        collections {
          id
          title
          parent {
            id
            title
          }
        }
      }
      """

      %{"data" => %{"collections" => results}} = execute_query(@api_path, conn, query)

      children_results = Enum.filter(results, fn c -> c["parent"] != nil end)
      assert Enum.count(children_results) >= 2

      child1_result = Enum.find(children_results, fn c -> c["id"] == child1.id end)
      child2_result = Enum.find(children_results, fn c -> c["id"] == child2.id end)

      assert child1_result["parent"]["id"] == parent.id
      assert child2_result["parent"]["id"] == parent.id
    end

    test "update collection with parent preserves parent relationship", %{conn: conn} do
      parent = insert(:collection)
      collection = insert(:collection, parent: parent)

      updated_title = "Updated Collection Title"

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          title: "#{updated_title}"
        }) {
          id
          title
          parent {
            id
            title
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert result["id"] == collection.id
      assert result["title"] == updated_title
      assert result["parent"]["id"] == parent.id
      assert result["parent"]["title"] == parent.title
    end

    test "delete collection with parent", %{conn: conn} do
      parent = insert(:collection)
      collection = insert(:collection, parent: parent)

      mutation = """
      mutation {
        deleteCollection(id: "#{collection.id}")
      }
      """

      %{"data" => %{"deleteCollection" => true}} = execute_query(@api_path, conn, mutation)

      {:error, :not_found} = Collections.get_collection(collection.id)

      {:ok, parent_still_exists} = Collections.get_collection(parent.id)
      assert parent_still_exists.id == parent.id
    end

    test "retrieve collection without parent field requested", %{conn: conn} do
      parent = insert(:collection)
      collection = insert(:collection, parent: parent)

      query = """
      {
        collection(id: "#{collection.id}") {
          id
          title
        }
      }
      """

      %{"data" => %{"collection" => result}} = execute_query(@api_path, conn, query)

      assert result["id"] == collection.id
      assert result["title"] == collection.title
      refute Map.has_key?(result, "parent")
    end

    test "list collections without parent field requested", %{conn: conn} do
      parent = insert(:collection)
      insert(:collection, parent: parent)

      query = """
      {
        collections(limit: 5) {
          id
          title
        }
      }
      """

      %{"data" => %{"collections" => results}} = execute_query(@api_path, conn, query)

      Enum.each(results, fn result ->
        assert Map.has_key?(result, "id")
        assert Map.has_key?(result, "title")
        refute Map.has_key?(result, "parent")
      end)
    end
  end

  describe "comics relationships" do
    test "retrieve collection with comics", %{conn: conn} do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic2.id)

      query = """
      {
        collection(id: "#{collection.id}") {
          id
          title
          comics {
            id
            title
            author
          }
        }
      }
      """

      %{"data" => %{"collection" => result}} = execute_query(@api_path, conn, query)

      assert result["id"] == collection.id
      assert result["title"] == collection.title
      assert Enum.count(result["comics"]) == 2

      comic_ids = Enum.map(result["comics"], & &1["id"])
      assert Enum.member?(comic_ids, comic1.id)
      assert Enum.member?(comic_ids, comic2.id)
    end

    test "list collections with comics", %{conn: conn} do
      collection1 = insert(:collection)
      collection2 = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection1.id, comic1.id)
      {:ok, _} = Collections.add_to_collection(collection2.id, comic2.id)

      query = """
      {
        collections {
          id
          title
          comics {
            id
            title
          }
        }
      }
      """

      %{"data" => %{"collections" => results}} = execute_query(@api_path, conn, query)

      collection1_result = Enum.find(results, fn c -> c["id"] == collection1.id end)
      collection2_result = Enum.find(results, fn c -> c["id"] == collection2.id end)

      assert collection1_result["comics"] |> Enum.map(& &1["id"]) |> Enum.member?(comic1.id)
      assert collection2_result["comics"] |> Enum.map(& &1["id"]) |> Enum.member?(comic2.id)
    end

    test "retrieve collection without comics field requested", %{conn: conn} do
      collection = insert(:collection)
      comic = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic.id)

      query = """
      {
        collection(id: "#{collection.id}") {
          id
          title
        }
      }
      """

      %{"data" => %{"collection" => result}} = execute_query(@api_path, conn, query)

      assert result["id"] == collection.id
      assert result["title"] == collection.title
      refute Map.has_key?(result, "comics")
    end

    test "retrieve collection with empty comics list", %{conn: conn} do
      collection = insert(:collection)

      query = """
      {
        collection(id: "#{collection.id}") {
          id
          title
          comics {
            id
            title
          }
        }
      }
      """

      %{"data" => %{"collection" => result}} = execute_query(@api_path, conn, query)

      assert result["id"] == collection.id
      assert result["title"] == collection.title
      assert result["comics"] == []
    end
  end

  describe "update collection with comics" do
    test "add comics to empty collection", %{conn: conn} do
      collection = insert(:collection, title: "Original Title")
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: ["#{comic1.id}", "#{comic2.id}"]
        }) {
          id
          title
          comics {
            id
            title
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert result["id"] == collection.id
      assert result["title"] == "Original Title"
      assert Enum.count(result["comics"]) == 2

      comic_ids = Enum.map(result["comics"], & &1["id"])
      assert Enum.member?(comic_ids, comic1.id)
      assert Enum.member?(comic_ids, comic2.id)
    end

    test "add comics to collection with existing comics", %{conn: conn} do
      collection = insert(:collection)
      existing_comic = insert(:comic)
      new_comic1 = insert(:comic)
      new_comic2 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, existing_comic.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: ["#{new_comic1.id}", "#{new_comic2.id}"]
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 3
      comic_ids = Enum.map(result["comics"], & &1["id"])
      assert Enum.member?(comic_ids, existing_comic.id)
      assert Enum.member?(comic_ids, new_comic1.id)
      assert Enum.member?(comic_ids, new_comic2.id)
    end

    test "remove comics from collection", %{conn: conn} do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)
      comic3 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic2.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic3.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToRemove: ["#{comic1.id}", "#{comic3.id}"]
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 1
      assert Enum.at(result["comics"], 0)["id"] == comic2.id
    end

    test "add and remove comics in same operation", %{conn: conn} do
      collection = insert(:collection)
      existing_comic1 = insert(:comic)
      existing_comic2 = insert(:comic)
      new_comic = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, existing_comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, existing_comic2.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: ["#{new_comic.id}"]
          comicsToRemove: ["#{existing_comic1.id}"]
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 2
      comic_ids = Enum.map(result["comics"], & &1["id"])
      refute Enum.member?(comic_ids, existing_comic1.id)
      assert Enum.member?(comic_ids, existing_comic2.id)
      assert Enum.member?(comic_ids, new_comic.id)
    end

    test "add existing comic (idempotent)", %{conn: conn} do
      collection = insert(:collection)
      comic = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: ["#{comic.id}"]
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 1
      assert Enum.at(result["comics"], 0)["id"] == comic.id
    end

    test "remove non-existent comic (idempotent)", %{conn: conn} do
      collection = insert(:collection)
      existing_comic = insert(:comic)
      non_existent_comic = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, existing_comic.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToRemove: ["#{non_existent_comic.id}"]
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 1
      assert Enum.at(result["comics"], 0)["id"] == existing_comic.id
    end

    test "add same comic in both add and remove (add then remove - comic ends up removed)", %{conn: conn} do
      collection = insert(:collection)
      comic = insert(:comic)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: ["#{comic.id}"]
          comicsToRemove: ["#{comic.id}"]
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert result["comics"] == []
    end

    test "add invalid comic ids (skips invalid, processes valid)", %{conn: conn} do
      collection = insert(:collection)
      valid_comic = insert(:comic)
      invalid_comic_id = Ecto.UUID.generate()

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: ["#{valid_comic.id}", "#{invalid_comic_id}"]
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 1
      assert Enum.at(result["comics"], 0)["id"] == valid_comic.id
    end

    test "update title and comics together", %{conn: conn} do
      collection = insert(:collection, title: "Original Title")
      comic = insert(:comic)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          title: "Updated Title"
          comicsToAdd: ["#{comic.id}"]
        }) {
          id
          title
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert result["id"] == collection.id
      assert result["title"] == "Updated Title"
      assert Enum.count(result["comics"]) == 1
      assert Enum.at(result["comics"], 0)["id"] == comic.id
    end

    test "update without comics fields (no change to existing comics)", %{conn: conn} do
      collection = insert(:collection, title: "Original Title")
      existing_comic = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, existing_comic.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          title: "Updated Title"
        }) {
          id
          title
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert result["title"] == "Updated Title"
      assert Enum.count(result["comics"]) == 1
      assert Enum.at(result["comics"], 0)["id"] == existing_comic.id
    end

    test "update collection with invalid id", %{conn: conn} do
      invalid_id = Ecto.UUID.generate()
      comic = insert(:comic)

      mutation = """
      mutation {
        updateCollection(id: "#{invalid_id}", input: {
          comicsToAdd: ["#{comic.id}"]
        }) {
          id
        }
      }
      """

      %{"errors" => [%{"message" => "Not found"}]} = execute_query(@api_path, conn, mutation)
    end

    test "bulk add multiple comics", %{conn: conn} do
      collection = insert(:collection)
      comics = insert_list(5, :comic)
      comic_ids = Enum.map(comics, & &1.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: #{inspect(comic_ids)}
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 5
      result_comic_ids = Enum.map(result["comics"], & &1["id"])

      Enum.each(comic_ids, fn comic_id ->
        assert Enum.member?(result_comic_ids, comic_id)
      end)
    end

    test "bulk remove multiple comics", %{conn: conn} do
      collection = insert(:collection)
      comics_to_keep = insert_list(2, :comic)
      comics_to_remove = insert_list(3, :comic)

      all_comics = comics_to_keep ++ comics_to_remove

      Enum.each(all_comics, fn comic ->
        {:ok, _} = Collections.add_to_collection(collection.id, comic.id)
      end)

      remove_ids = Enum.map(comics_to_remove, & &1.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToRemove: #{inspect(remove_ids)}
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 2
      result_comic_ids = Enum.map(result["comics"], & &1["id"])

      Enum.each(comics_to_keep, fn comic ->
        assert Enum.member?(result_comic_ids, comic.id)
      end)

      Enum.each(comics_to_remove, fn comic ->
        refute Enum.member?(result_comic_ids, comic.id)
      end)
    end

    test "complex operation: mix of valid/invalid adds and removes", %{conn: conn} do
      collection = insert(:collection)
      existing_comic1 = insert(:comic)
      existing_comic2 = insert(:comic)
      new_valid_comic = insert(:comic)
      invalid_comic_id = Ecto.UUID.generate()

      {:ok, _} = Collections.add_to_collection(collection.id, existing_comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, existing_comic2.id)

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: ["#{new_valid_comic.id}", "#{invalid_comic_id}"]
          comicsToRemove: ["#{existing_comic1.id}", "#{invalid_comic_id}"]
        }) {
          id
          comics {
            id
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      assert Enum.count(result["comics"]) == 2
      result_comic_ids = Enum.map(result["comics"], & &1["id"])

      refute Enum.member?(result_comic_ids, existing_comic1.id)
      assert Enum.member?(result_comic_ids, existing_comic2.id)
      assert Enum.member?(result_comic_ids, new_valid_comic.id)
    end

    test "collection comics preserve full comic data", %{conn: conn} do
      collection = insert(:collection)

      comic =
        insert(:comic,
          title: "Amazing Comic",
          author: "Great Author",
          description: "A wonderful story"
        )

      mutation = """
      mutation {
        updateCollection(id: "#{collection.id}", input: {
          comicsToAdd: ["#{comic.id}"]
        }) {
          id
          comics {
            id
            title
            author
            description
            resourceLocation
          }
        }
      }
      """

      %{"data" => %{"updateCollection" => result}} = execute_query(@api_path, conn, mutation)

      comic_result = Enum.at(result["comics"], 0)
      assert comic_result["id"] == comic.id
      assert comic_result["title"] == "Amazing Comic"
      assert comic_result["author"] == "Great Author"
      assert comic_result["description"] == "A wonderful story"
      assert comic_result["resourceLocation"] == comic.resource_location
    end
  end
end
