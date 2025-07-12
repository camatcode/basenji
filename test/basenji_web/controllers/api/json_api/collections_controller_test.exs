defmodule BasenjiWeb.JSONAPI.CollectionsControllerTest do
  use BasenjiWeb.ConnCase

  alias Basenji.Collections
  alias BasenjiWeb.JSONAPI.CollectionsController

  @moduletag :capture_log

  doctest CollectionsController

  @api_path "/api/json/collections"

  test "create collection", %{conn: conn} do
    %{title: title, description: desc, resource_location: location} = build(:collection)
    parent = insert(:collection)
    collection = %{title: title, description: desc, resource_location: location, parent_id: parent.id}
    include = "parent"

    body = TestHelper.JSONAPI.build_request_body("collection", nil, collection)

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post(@api_path <> "?include=#{include}", body)

    assert %{"data" => collection} = json_response(conn, 200)
    assert valid_collection?(collection)
  end

  test "get collection", %{conn: conn} do
    collection = insert(:collection)
    conn = get(conn, "#{@api_path}/#{collection.id}", %{})

    assert %{"data" => collection} = json_response(conn, 200)
    assert valid_collection?(collection)
  end

  test "update collection", %{conn: conn} do
    %{resource_location: loc} =
      collection = insert(:collection) |> Map.from_struct()

    comics = insert_list(3, :comic)

    Enum.each(comics, fn comic ->
      Collections.add_to_collection(collection.id, comic.id)
    end)

    new_parent = insert(:collection)

    changes = %{
      title: Faker.Lorem.sentence(),
      description: Faker.Lorem.paragraph(2),
      parent_id: new_parent.id
    }

    include = "parent,comics"
    body = TestHelper.JSONAPI.build_request_body("collection", collection.id, changes)

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("#{@api_path}/#{collection.id}" <> "?include=#{include}", body)

    assert %{"data" => updated} = json_response(conn, 200)
    assert valid_collection?(updated)

    # changed
    assert updated["attributes"]["description"] == changes.description
    assert updated["attributes"]["title"] == changes.title
    assert updated["attributes"]["parentId"] == changes.parent_id
    # unchanged
    assert updated["id"] == collection.id
    assert updated["attributes"]["resourceLocation"] == loc
  end

  test "delete collection", %{conn: conn} do
    collection = insert(:collection)
    conn = delete(conn, "#{@api_path}/#{collection.id}", %{})

    assert %{"data" => deleted} = json_response(conn, 200)
    assert deleted["id"] == collection.id

    {:error, :not_found} = Collections.get_collection(collection.id)
  end

  describe "list" do
    test "lists collections", %{conn: conn} do
      insert_list(100, :collection)
      conn = get(conn, @api_path, %{})

      assert %{"data" => collections} = json_response(conn, 200)
      refute Enum.empty?(collections)

      collections
      |> Enum.each(fn comic ->
        assert valid_collection?(comic)
      end)
    end

    test "search by", %{conn: conn} do
      collections = insert_list(10, :collection)

      Enum.each(collections, fn collection ->
        [:title, :resourceLocation, :description]
        |> Enum.each(fn search_term ->
          search_val = collection |> Map.from_struct() |> Map.get(search_term)
          conn = get(conn, @api_path, %{"filter" => %{"#{search_term}" => search_val}})
          assert %{"data" => results} = json_response(conn, 200)
          refute Enum.empty?(results)
          [_result] = Enum.filter(results, fn c -> c["id"] == collection.id end)
        end)
      end)
    end

    test "search_by time", %{conn: conn} do
      insert_list(10, :collection)
      :timer.sleep(1000)
      dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      inserted = insert(:collection)
      # inserted_after
      conn = get(conn, @api_path, %{"filter" => %{"inserted_after" => "#{dt}"}})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [_result] = Enum.filter(results, fn c -> c["id"] == inserted.id end)
      # inserted_before
      conn = get(conn, @api_path, %{"filter" => %{"inserted_before" => "#{dt}"}})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [] = Enum.filter(results, fn c -> c["id"] == inserted.id end)
      # updated_after
      updated_dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      {:ok, _updated} = Collections.update_collection(inserted, %{title: Faker.Lorem.sentence()})
      conn = get(conn, @api_path, %{"filter" => %{"updated_after" => "#{updated_dt}"}})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [_result] = Enum.filter(results, fn c -> c["id"] == inserted.id end)
      # updated_before
      conn = get(conn, @api_path, %{"filter" => %{"updated_before" => "#{updated_dt}"}})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [] = Enum.filter(results, fn c -> c["id"] == inserted.id end)
    end

    test "generic search", %{conn: conn} do
      %{id: a} = insert(:collection, title: "Baz and Peace", description: "Thrilling murder mystery comics", parent: nil)

      %{id: b} =
        insert(:collection, title: "Of foo and bar, or On The 25-fold Path", description: "Romance novels", parent: nil)

      %{id: c} =
        insert(:collection,
          title: "Potion-seller's guide to the galaxy",
          description: "25 comics, pretty dense",
          parent: nil
        )

      [{"and", [a, b]}, {"the", [b, c]}, {"comics", [a, c]}, {"25", [b, c]}]
      |> Enum.each(fn {term, expected} ->
        conn = get(conn, @api_path, %{"filter" => term, "sort" => "title"})
        assert %{"data" => results} = json_response(conn, 200)
        assert expected == results |> Enum.map(fn c -> c["id"] end)
      end)
    end
  end

  describe "collections with comic relationships" do
    test "PATCH /collections/:id - update collection with comics relationship", %{conn: conn} do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      comics_relationship = TestHelper.JSONAPI.build_comics_relationship([comic1.id, comic2.id])

      body =
        TestHelper.JSONAPI.build_request_body(
          "collection",
          collection.id,
          %{"title" => "Updated Collection"},
          comics_relationship
        )

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}", body)

      assert json_response(conn, 200)

      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(updated_collection.comics, & &1.id)
      assert length(comic_ids) == 2
      assert Enum.member?(comic_ids, comic1.id)
      assert Enum.member?(comic_ids, comic2.id)
      assert updated_collection.title == "Updated Collection"
    end

    test "PATCH /collections/:id - replace existing comics in collection", %{conn: conn} do
      collection = insert(:collection)
      old_comic = insert(:comic)
      new_comic1 = insert(:comic)
      new_comic2 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, old_comic.id)

      comics_relationship = TestHelper.JSONAPI.build_comics_relationship([new_comic1.id, new_comic2.id])
      body = TestHelper.JSONAPI.build_request_body("collection", collection.id, %{}, comics_relationship)

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}", body)

      assert json_response(conn, 200)

      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(updated_collection.comics, & &1.id)
      assert length(comic_ids) == 2
      assert Enum.member?(comic_ids, new_comic1.id)
      assert Enum.member?(comic_ids, new_comic2.id)
      refute Enum.member?(comic_ids, old_comic.id)
    end

    test "PATCH /collections/:id - clear all comics from collection", %{conn: conn} do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic2.id)

      request_body = %{
        "data" => %{
          "type" => "collection",
          "id" => collection.id,
          "relationships" => %{
            "comics" => %{
              "data" => []
            }
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}", request_body)

      assert json_response(conn, 200)

      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      assert Enum.empty?(updated_collection.comics)
    end

    test "PATCH /collections/:id - update only attributes without affecting relationships", %{conn: conn} do
      collection = insert(:collection)
      comic = insert(:comic)

      # Add initial comic
      {:ok, _} = Collections.add_to_collection(collection.id, comic.id)

      request_body = %{
        "data" => %{
          "type" => "collection",
          "id" => collection.id,
          "attributes" => %{
            "title" => "Updated Title Only"
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}", request_body)

      assert json_response(conn, 200)

      # Verify the comic relationship was preserved
      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(updated_collection.comics, & &1.id)
      assert length(comic_ids) == 1
      assert Enum.member?(comic_ids, comic.id)
      assert updated_collection.title == "Updated Title Only"
    end

    test "GET /collections/:id - includes comics relationship data when requested", %{conn: conn} do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic2.id)

      conn = get(conn, "#{@api_path}/#{collection.id}?include=comics")

      response = json_response(conn, 200)

      assert response["data"]["relationships"]["comics"]["data"]
      comics_data = response["data"]["relationships"]["comics"]["data"]
      assert length(comics_data) == 2

      comic_ids = Enum.map(comics_data, fn comic -> comic["id"] end)
      assert Enum.member?(comic_ids, comic1.id)
      assert Enum.member?(comic_ids, comic2.id)

      assert response["included"]
      assert length(response["included"]) == 2
    end
  end

  describe "validation and error handling" do
    test "PATCH with malformed relationship data", %{conn: conn} do
      collection = insert(:collection)

      request_body = %{
        "data" => %{
          "type" => "collection",
          "id" => collection.id,
          "relationships" => %{
            "comics" => %{"data" => "this-should-be-an-array"}
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}", request_body)

      response = json_response(conn, 400)
      assert response["error"] || response["errors"]
    end

    test "PATCH with invalid comic UUID in relationship", %{conn: conn} do
      collection = insert(:collection)

      request_body = %{
        "data" => %{
          "type" => "collection",
          "id" => collection.id,
          "relationships" => %{
            "comics" => %{
              "data" => [
                %{"type" => "comic", "id" => "not-a-uuid"}
              ]
            }
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}", request_body)

      response = json_response(conn, 400)
      assert response["error"] || response["errors"]
    end

    test "PATCH with non-existent comic UUID in relationship", %{conn: conn} do
      collection = insert(:collection)
      fake_comic_id = Ecto.UUID.generate()

      comics_relationship = TestHelper.JSONAPI.build_comics_relationship([fake_comic_id])
      body = TestHelper.JSONAPI.build_request_body("collection", collection.id, %{}, comics_relationship)

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}", body)

      assert json_response(conn, 200)

      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      assert Enum.empty?(updated_collection.comics)
    end

    test "POST with missing required attributes", %{conn: conn} do
      body = TestHelper.JSONAPI.build_request_body("collection", nil, %{"description" => "Has description but no title"})

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post(@api_path, body)

      response = json_response(conn, 400)
      assert response["error"] || response["errors"]
      error_text = response["error"] || Enum.map_join(response["errors"], " ", & &1["detail"])
      assert String.contains?(error_text, "title")
    end

    test "GET with invalid collection UUID", %{conn: conn} do
      conn = get(conn, "#{@api_path}/not-a-uuid")

      response = json_response(conn, 400)
      assert response["error"]
    end

    test "PATCH with empty relationship data", %{conn: conn} do
      collection = insert(:collection)
      comic = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic.id)

      request_body = %{
        "data" => %{
          "type" => "collection",
          "id" => collection.id,
          "relationships" => %{
            "comics" => %{
              "data" => []
            }
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}", request_body)

      assert json_response(conn, 200)

      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      assert Enum.empty?(updated_collection.comics)
    end
  end

  defp valid_collection?(%{"attributes" => attributes, "id" => id, "type" => "collection"} = collection) do
    assert id
    assert attributes["title"]
    assert attributes["description"]
    assert attributes["resourceLocation"]
    assert attributes["insertedAt"]
    assert attributes["updatedAt"]

    if Map.has_key?(collection, "relationships") do
      assoc_comics = collection["relationships"]["comics"]
      parent = collection["relationships"]["parent"]
      if assoc_comics, do: refute(Enum.empty?(assoc_comics["data"]))
      if parent, do: assert(parent["data"]["id"])
    end

    true
  end
end
