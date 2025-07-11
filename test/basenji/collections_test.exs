defmodule Basenji.CollectionsTest do
  use Basenji.DataCase

  alias Basenji.Collections

  @moduletag :capture_log

  doctest Collections

  describe "crud" do
    test "create" do
      attrs = %{title: Faker.Lorem.sentence(), description: Faker.Lorem.paragraph(2)}

      {:ok, collection} = Collections.create_collection(attrs)

      assert collection.title == attrs[:title]
      assert collection.description == attrs[:description]

      comics = insert_list(3, :comic)

      Enum.each(comics, fn comic ->
        {:ok, coll_comic} = Collections.add_to_collection(collection, comic)
        assert coll_comic.comic_id == comic.id
        assert coll_comic.collection_id == collection.id
      end)

      # test unique constraint
      {:ok, already_made} = Collections.create_collection(attrs)
      assert collection.id == already_made.id
    end

    test "create collections" do
      attrs_list = [
        %{title: Faker.Lorem.sentence(), description: Faker.Lorem.paragraph(2)},
        %{title: Faker.Lorem.sentence(), description: Faker.Lorem.paragraph(2)}
      ]

      {:ok, collections} = Collections.create_collections(attrs_list)
      assert Enum.count(collections) == 2

      {:ok, already_made} = Collections.create_collections(attrs_list)
      assert Enum.count(already_made) == 2

      assert 2 == Collections.list_collections() |> Enum.count()
    end

    test "get" do
      collection = insert(:collection)
      comics = insert_list(3, :comic)

      {:ok, c_comics} = Collections.add_to_collection(collection, comics)

      Enum.each(comics, fn comic ->
        [coll_comic] = c_comics |> Enum.filter(fn c_comic -> c_comic.comic_id == comic.id end)
        assert coll_comic.comic_id == comic.id
        assert coll_comic.collection_id == collection.id
      end)

      Collections.get_collection(collection.id, preload: [:collection_comics, :comics])
    end

    test "from_directory" do
      resource_dir = Basenji.Application.get_comics_directory()

      {:ok, _} =
        Collections.create_collection(%{
          title: "My Comics",
          description: Faker.Lorem.sentence(),
          resource_location: resource_dir
        })

      TestHelper.drain_queues([:collection, :comic])

      made_collections =
        Collections.list_collections(preload: [:collection_comics])
        |> Enum.filter(fn coll -> coll.parent_id && not Enum.empty?(coll.collection_comics) end)

      assert Enum.count(made_collections) > 3

      Enum.each(
        made_collections,
        fn collection -> assert valid_collection?(collection) end
      )
    end

    test "update" do
      [collection | _] = collections = insert_list(10, :collection)
      # a collection cannot make itself a parent
      {:error, _} = Collections.update_collection(collection, %{parent_id: collection.id})

      collections
      |> Enum.each(fn collection ->
        new_parent = (collections -- [collection]) |> Enum.random()
        new_title = Faker.Lorem.sentence()
        new_description = Faker.Lorem.paragraph(2)

        {:ok, updated} =
          Collections.update_collection(collection, %{
            parent_id: new_parent.id,
            title: new_title,
            description: new_description
          })

        assert updated.parent_id == new_parent.id
        assert updated.title == new_title
        assert updated.description == new_description
      end)
    end

    test "delete" do
      collections = insert_list(10, :collection)

      Enum.each(collections, fn collection ->
        collection_comic = insert(:collection_comic, collection_id: collection.id)

        {:ok, _} = Collections.remove_from_collection(collection.id, collection_comic.comic_id)

        # can delete
        {:ok, _} = Collections.delete_collection(collection)

        # comic unaffected
        {:ok, _} = Basenji.Comics.get_comic(collection_comic.comic_id)
      end)
    end
  end

  describe "search and sort" do
    test "list" do
      collections = insert_list(10, :collection)

      collections
      |> Enum.each(fn collection ->
        insert_list(3, :collection_comic, collection_id: collection.id)
      end)

      retrieved = Collections.list_collections(preload: [collection_comics: [:comic]])

      retrieved
      |> Enum.each(fn collection ->
        assert valid_collection?(collection)
      end)
    end

    test "offset/limit" do
      insert_list(100, :collection)
      collections = Collections.list_collections(limit: 10)
      assert Enum.count(collections) == 10

      0..9
      |> Enum.reduce(nil, fn page_idx, offset ->
        collections = Collections.list_collections(limit: 10, offset: offset)
        assert Enum.count(collections) == 10
        (page_idx + 1) * 10
      end)

      assert Enum.empty?(Collections.list_collections(limit: 10, offset: 2000))
    end

    test "search by" do
      insert_list(10, :collection)
      collections = Collections.list_collections()

      Enum.each(collections, fn collection ->
        [^collection] = Collections.list_collections(title: collection.title)
        [^collection] = Collections.list_collections(description: collection.description)

        if collection.parent_id do
          results = Collections.list_collections(parent: collection.parent_id)
          assert Enum.member?(results, collection)
        end
      end)
    end

    test "search by time" do
      insert_list(10, :collection, parent: nil)
      dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      insert(:collection, parent: nil)
      [collection] = Collections.list_collections(inserted_after: dt)
      results = Collections.list_collections(inserted_before: dt)
      refute Enum.member?(results, collection)

      updated_dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)

      {:ok, %{id: updated_id}} =
        Collections.update_collection(collection, %{title: Faker.Lorem.sentence(), description: Faker.Lorem.paragraph(2)})

      [%{id: ^updated_id}] = Collections.list_collections(updated_after: updated_dt)
    end

    test "generic search" do
      %{id: a} = insert(:collection, title: "Baz and Peace", description: "Thrilling murder mystery comics", parent: nil)

      %{id: b} =
        insert(:collection, title: "Of foo and bar, or On The 25-fold Path", description: "Romance novels", parent: nil)

      %{id: c} =
        insert(:collection,
          title: "Potion-seller's guide to the galaxy",
          description: "25 comics, pretty dense",
          parent: nil
        )

      [%{id: ^a}, %{id: ^b}] = Collections.list_collections(search: "and", order_by: :title)
      [%{id: ^b}, %{id: ^c}] = Collections.list_collections(search: "the", order_by: :title)
      [%{id: ^a}, %{id: ^c}] = Collections.list_collections(search: "comics", order_by: :title)
    end
  end

  describe "update collection with comics" do
    test "basic add comics functionality" do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      {:ok, _} =
        Collections.update_collection_with_comics(collection.id, %{
          comics_to_add: [comic1.id, comic2.id]
        })

      {:ok, collection_with_comics} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(collection_with_comics.comics, & &1.id)
      assert Enum.member?(comic_ids, comic1.id)
      assert Enum.member?(comic_ids, comic2.id)
      assert Enum.count(comic_ids) == 2
    end

    test "basic remove comics functionality" do
      collection = insert(:collection)
      comic1 = insert(:comic)
      comic2 = insert(:comic)

      {:ok, _} = Collections.add_to_collection(collection.id, comic1.id)
      {:ok, _} = Collections.add_to_collection(collection.id, comic2.id)

      {:ok, _} =
        Collections.update_collection_with_comics(collection.id, %{
          comics_to_remove: [comic1.id]
        })

      {:ok, collection_with_comics} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(collection_with_comics.comics, & &1.id)
      refute Enum.member?(comic_ids, comic1.id)
      assert Enum.member?(comic_ids, comic2.id)
      assert Enum.count(comic_ids) == 1
    end

    test "add then remove same comic in one operation" do
      collection = insert(:collection)
      comic = insert(:comic)

      {:ok, _} =
        Collections.update_collection_with_comics(collection.id, %{
          comics_to_add: [comic.id],
          comics_to_remove: [comic.id]
        })

      {:ok, collection_with_comics} = Collections.get_collection(collection.id, preload: [:comics])
      assert Enum.empty?(collection_with_comics.comics)
    end

    test "skip invalid comic IDs" do
      collection = insert(:collection)
      valid_comic = insert(:comic)
      invalid_comic_id = Ecto.UUID.generate()

      {:ok, _} =
        Collections.update_collection_with_comics(collection.id, %{
          comics_to_add: [valid_comic.id, invalid_comic_id]
        })

      {:ok, collection_with_comics} = Collections.get_collection(collection.id, preload: [:comics])
      comic_ids = Enum.map(collection_with_comics.comics, & &1.id)
      assert Enum.count(comic_ids) == 1
      assert Enum.member?(comic_ids, valid_comic.id)
    end

    test "transaction atomicity - rollback on collection update failure" do
      collection = insert(:collection, title: "Original Title")
      comic = insert(:comic)

      {:error, changeset} =
        Collections.update_collection_with_comics(collection.id, %{
          title: nil,
          comics_to_add: [comic.id]
        })

      {:ok, unchanged_collection} = Collections.get_collection(collection.id, preload: [:comics])
      assert unchanged_collection.title == "Original Title"
      assert Enum.empty?(unchanged_collection.comics)

      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end

    test "update collection fields and comics together" do
      collection = insert(:collection, title: "Original Title")
      comic = insert(:comic)

      {:ok, updated_collection} =
        Collections.update_collection_with_comics(collection.id, %{
          title: "Updated Title",
          comics_to_add: [comic.id]
        })

      assert updated_collection.title == "Updated Title"

      {:ok, collection_with_comics} = Collections.get_collection(collection.id, preload: [:comics])
      assert collection_with_comics.title == "Updated Title"
      comic_ids = Enum.map(collection_with_comics.comics, & &1.id)
      assert Enum.count(comic_ids) == 1
      assert Enum.member?(comic_ids, comic.id)
    end
  end

  defp valid_collection?(collection) do
    assert collection.id
    assert collection.title
    refute Enum.empty?(collection.collection_comics)
    assert collection.inserted_at
    assert collection.updated_at

    true
  end
end
