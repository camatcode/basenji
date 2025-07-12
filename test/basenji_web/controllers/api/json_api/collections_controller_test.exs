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

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post(@api_path <> "?include=#{include}", %{"data" => %{"attributes" => collection, "type" => "collection"}})

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

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("#{@api_path}/#{collection.id}" <> "?include=#{include}", %{
        "data" => %{"attributes" => changes, "type" => "collection"}
      })

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

  describe "comics relationship endpoints" do
    test "GET /collections/:id/relationships/comics - show comics relationship", %{conn: conn} do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic2.id)

      conn = get(conn, "#{@api_path}/#{collection.id}/relationships/comics")

      assert %{"data" => comics_data} = json_response(conn, 200)
      assert length(comics_data) == 2

      comic_ids = Enum.map(comics_data, & &1["id"])
      assert Enum.member?(comic_ids, comic1.id)
      assert Enum.member?(comic_ids, comic2.id)

      Enum.each(comics_data, fn comic_data ->
        assert comic_data["type"] == "comic"
        assert comic_data["id"]
      end)
    end

    test "POST /collections/:id/relationships/comics - add comics to collection", %{conn: conn} do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      request_body = %{
        "data" => [
          %{"type" => "comic", "id" => comic1.id},
          %{"type" => "comic", "id" => comic2.id}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("#{@api_path}/#{collection.id}/relationships/comics", request_body)

      assert json_response(conn, 204)

      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(updated_collection.comics, & &1.id)
      assert Enum.member?(comic_ids, comic1.id)
      assert Enum.member?(comic_ids, comic2.id)
    end

    test "DELETE /collections/:id/relationships/comics - remove comics from collection", %{conn: conn} do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)
      comic3 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic2.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic3.id)

      request_body = %{
        "data" => [
          %{"type" => "comic", "id" => comic1.id},
          %{"type" => "comic", "id" => comic3.id}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> delete("#{@api_path}/#{collection.id}/relationships/comics", request_body)

      assert json_response(conn, 204)

      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(updated_collection.comics, & &1.id)
      assert length(comic_ids) == 1
      assert Enum.member?(comic_ids, comic2.id)
    end

    test "PATCH /collections/:id/relationships/comics - replace all comics", %{conn: conn} do
      collection = insert(:collection)
      old_comic = insert(:comic)
      new_comic = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, old_comic.id)

      request_body = %{
        "data" => [
          %{"type" => "comic", "id" => new_comic.id}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("#{@api_path}/#{collection.id}/relationships/comics", request_body)

      assert json_response(conn, 204)

      {:ok, updated_collection} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(updated_collection.comics, & &1.id)
      assert length(comic_ids) == 1
      assert Enum.member?(comic_ids, new_comic.id)
      refute Enum.member?(comic_ids, old_comic.id)
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
