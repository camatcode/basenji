defmodule Basenji.CollectionsTest do
  use Basenji.DataCase

  alias Basenji.Collections
  alias Basenji.Comic

  @moduletag :capture_log

  doctest Collections

  test "from_directory" do
    resource_dir = Basenji.Application.get_comics_directory()

    Comic.formats()
    |> Enum.each(fn format ->
      dirs = Path.wildcard("#{resource_dir}/**/#{format}")
      refute Enum.empty?(dirs)

      Enum.each(dirs, fn dir ->
        title = "#{format}_#{System.monotonic_time()}"
        description = Faker.Lorem.paragraph(2)
        {:ok, collection} = Collections.from_directory(%{title: title, description: description}, dir)
        assert valid_collection?(collection)
      end)
    end)
  end

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
  end

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
        Collections.update_collection(collection, %{parent_id: new_parent.id, title: new_title, description: new_description})

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

  defp valid_collection?(collection) do
    assert collection.id
    assert collection.title
    assert collection.description
    refute Enum.empty?(collection.collection_comics)
    assert collection.inserted_at
    assert collection.updated_at

    true
  end
end
