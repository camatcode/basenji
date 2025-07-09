defmodule Basenji.ComicsTest do
  use Basenji.DataCase

  alias Basenji.Comics

  describe "crud" do
    test "create_comic/2" do
      to_assert = build_list(100, :comic)
      refute Enum.empty?(to_assert)

      comics =
        Enum.map(to_assert, fn comic ->
          {:ok, created} =
            comic
            |> Map.from_struct()
            |> Comics.create_comic()

          assert created.id
          assert created.title == comic.title

          created
        end)

      # test unique constraint
      already_inserted_comic_id = hd(comics).id
      [already_inserted | _] = to_assert

      {:ok, %{id: ^already_inserted_comic_id}} =
        already_inserted
        |> Map.from_struct()
        |> Comics.create_comic()
    end

    test "create_comics/2" do
      to_assert =
        build_list(100, :comic)
        |> Enum.map(&Map.from_struct/1)

      refute Enum.empty?(to_assert)
      {:ok, comics} = Comics.create_comics(to_assert)
      assert Enum.count(comics) == 100

      # test unique constraint
      {:ok, inserted_again} = Comics.create_comics(to_assert)
      assert Enum.count(inserted_again) == 100

      assert 100 == Comics.list_comics() |> Enum.count()
    end

    test "from_resource/2" do
      resource_dir = Basenji.Application.get_comics_directory()

      Basenji.Comic.formats()
      |> Enum.each(fn format ->
        files = Path.wildcard("#{resource_dir}/**/*.#{format}")
        refute Enum.empty?(files)

        files
        |> Enum.each(fn file ->
          {:ok, comic} = Comics.from_resource(file)
          TestHelper.drain_queue(:comic)
          {:ok, comic} = Comics.get_comic(comic.id)
          assert comic.title
          assert comic.page_count
          assert comic.resource_location
        end)
      end)
    end

    test "get_comic/2" do
      asserted = insert_list(100, :comic)
      refute Enum.empty?(asserted)

      Enum.each(asserted, fn comic ->
        assert {:ok, ^comic} = Comics.get_comic(comic.id)
      end)

      # check collection
      collection = insert(:collection)
      [comic | _] = asserted
      {:ok, %{collection_id: collection_id}} = Basenji.Collections.add_to_collection(collection, comic)

      {:ok, %{member_collections: [%{id: ^collection_id}]}} =
        Comics.get_comic(comic.id, preload: [:member_collections])
    end

    test "update_comic/2" do
      asserted = insert_list(100, :comic)
      refute Enum.empty?(asserted)

      Enum.each(asserted, fn comic ->
        updated_attrs = %{
          title: Faker.Lorem.sentence(),
          author: Faker.Person.name(),
          description: Faker.Lorem.paragraph(2),
          released_year: Enum.random(2015..2025),
          page_count: Enum.random(1..1000)
        }

        {:ok, updated} = Comics.update_comic(comic, updated_attrs)
        assert updated.title == updated_attrs.title
        assert updated.author == updated_attrs.author
        assert updated.description == updated_attrs.description
        assert updated.released_year == updated_attrs.released_year
        assert updated.page_count == updated_attrs.page_count
      end)
    end

    test "delete_comic/2" do
      to_delete = insert_list(100, :comic)
      refute Enum.empty?(to_delete)

      Enum.each(to_delete, fn comic ->
        # Either by ID or by struct
        ref = Enum.random([comic, comic.id])
        {:ok, deleted} = Comics.delete_comic(ref)
        assert comic.id == deleted.id
        {:error, :not_found} = Comics.get_comic(deleted.id)
      end)
    end
  end

  describe "search and sort" do
    test "list_comics/1" do
      expected_count = 100
      asserted = insert_list(expected_count, :comic)
      retrieved = Comics.list_comics()
      assert Enum.count(retrieved) == expected_count

      Enum.each(asserted, fn comic ->
        assert [^comic] = Enum.filter(retrieved, &(&1.id == comic.id))
        assert comic.title
        assert comic.description
        assert comic.author
        assert comic.resource_location
        assert comic.released_year > 0
        assert comic.page_count > 0
        assert comic.format
        assert comic.byte_size > 0
      end)
    end

    test "offset/limit" do
      insert_list(100, :comic)
      comics = Comics.list_comics(limit: 10)
      assert Enum.count(comics) == 10

      0..9
      |> Enum.reduce(nil, fn page_idx, offset ->
        comics = Comics.list_comics(limit: 10, offset: offset)
        assert Enum.count(comics) == 10
        (page_idx + 1) * 10
      end)

      assert Enum.empty?(Comics.list_comics(limit: 10, offset: 200))
    end

    test "search by" do
      comics = insert_list(10, :comic)

      Enum.each(comics, fn comic ->
        [^comic] = Comics.list_comics(title: comic.title)
        [^comic] = Comics.list_comics(author: comic.author)

        results = Comics.list_comics(resource_location: comic.resource_location)
        assert Enum.member?(results, comic)

        results = Comics.list_comics(format: comic.format)
        assert Enum.member?(results, comic)

        results = Comics.list_comics(released_year: comic.released_year)
        assert Enum.member?(results, comic)
      end)

      # based on time
      dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      inserted = insert(:comic)
      [^inserted] = Comics.list_comics(inserted_after: dt)
      results = Comics.list_comics(inserted_before: dt)
      refute Enum.member?(results, inserted)

      updated_dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      {:ok, updated} = Comics.update_comic(inserted, %{title: Faker.Lorem.sentence()})
      [^updated] = Comics.list_comics(updated_after: updated_dt)

      results = Comics.list_comics(updated_before: updated_dt)
      refute Enum.member?(results, updated)
    end

    test "generic search" do
      a =
        insert(:comic,
          title: "Baz and Peace",
          author: "Arthur Smith",
          description: "A thrilling murder mystery"
        )

      b =
        insert(:comic,
          title: "Of foo and bar, or On The 25-fold Path",
          author: "Jane Smith",
          description: "Her best romance novel"
        )

      c =
        insert(:comic,
          title: "Potion-seller's guide to the galaxy",
          author: "Sam Major",
          description: "25 chapters of dense reading"
        )

      [^a, ^b] = Comics.list_comics(search: "and", order_by: :title)
      [^b, ^c] = Comics.list_comics(search: "or", order_by: :title)
      [^a, ^b] = Comics.list_comics(search: "it", order_by: :title)
      [^b, ^c] = Comics.list_comics(search: "25", order_by: :title)
    end
  end

  test "get_page" do
    comic = insert(:comic)

    1..comic.page_count
    |> Enum.each(fn page ->
      ref = Enum.random([comic, comic.id])
      {:ok, bytes, mime} = Comics.get_page(ref, page)
      assert mime == "image/jpg"
      refute bytes == <<>>
    end)

    # overflow
    {:error, :not_found} = Comics.get_page(comic, comic.page_count + 1)

    # underflow
    {:error, :not_found} = Comics.get_page(comic, -1)
  end

  test "stream_pages" do
    comic = insert(:comic)

    {:ok, stream} = Comics.stream_pages(comic)
    pages = stream |> Enum.to_list()
    assert Enum.count(pages) == comic.page_count

    Enum.each(pages, fn page_stream ->
      bin_list = page_stream |> Enum.to_list()
      refute Enum.empty?(bin_list)
    end)
  end

  test "get_image_preview" do
    %{resource_location: loc} = build(:comic)
    {:ok, comic} = Comics.create_comic(%{resource_location: loc})

    {:error, :no_preview} = Comics.get_image_preview(comic.id)
    %{failure: 0} = TestHelper.drain_queue(:comic)
    {:ok, bytes} = Comics.get_image_preview(comic.id)
    assert byte_size(bytes) > 0
  end
end
