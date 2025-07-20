defmodule Basenji.ComicsTest do
  use Basenji.DataCase

  alias Basenji.Comic
  alias Basenji.Comics

  @moduletag :capture_log

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

      assert 100 == Comics.count_comics()
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

      # Test bad UUID
      assert {:error, :not_found} = Comics.get_comic("1234-1234")
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

      assert 2 == Comics.count_comics(search: "and", order_by: :title)
      assert 2 == Comics.count_comics(search: "and", order_by: :title)
      assert 2 == Comics.count_comics(search: "or", order_by: :title)
      assert 2 == Comics.count_comics(search: "it", order_by: :title)
      assert 2 == Comics.count_comics(search: "25", order_by: :title)
    end
  end

  test "get_page" do
    comic = insert(:comic)

    1..comic.page_count
    |> Enum.each(fn page ->
      ref = Enum.random([comic, comic.id])
      {:ok, bytes, mime} = Comics.get_page(ref, page)
      assert mime == "image/jpeg"
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

  describe "optimization" do
    test "create_optimized_comic/2 creates a clone with optimization relationship" do
      original = insert(:comic)
      optimized_location = "/tmp/optimized_#{System.monotonic_time()}.cbz"

      # Create a dummy optimized file for testing
      File.touch!(optimized_location)
      on_exit(fn -> File.rm!(optimized_location) end)

      {:ok, optimized} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location,
          # Smaller than original
          byte_size: 1000
        })

      # Verify the optimized comic has correct attributes cloned
      assert optimized.title == original.title
      assert optimized.author == original.author
      assert optimized.description == original.description
      assert optimized.released_year == original.released_year
      assert optimized.page_count == original.page_count
      assert optimized.format == original.format

      # Verify optimization-specific attributes
      assert optimized.resource_location == optimized_location
      assert optimized.byte_size == 1000
      assert optimized.original_id == original.id
      assert is_nil(optimized.optimized_id)

      # Verify original is updated to point to optimized
      {:ok, updated_original} = Comics.get_comic(original.id)
      assert updated_original.optimized_id == optimized.id
    end

    test "create_optimized_comic/2 with overrides applies custom attributes" do
      original = insert(:comic, title: "Original Title", description: "Original description")
      optimized_location = "/tmp/optimized_#{System.monotonic_time()}.cbz"

      File.touch!(optimized_location)
      on_exit(fn -> File.rm!(optimized_location) end)

      {:ok, optimized} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location,
          # Override
          description: "Optimized description",
          byte_size: 500
        })

      # Cloned
      assert optimized.title == original.title
      # Overridden
      assert optimized.description == "Optimized description"
      assert optimized.resource_location == optimized_location
      assert optimized.byte_size == 500
    end

    test "cannot create optimized version of already optimized comic" do
      original = insert(:comic)
      optimized_location_1 = "/tmp/optimized1_#{System.monotonic_time()}.cbz"
      optimized_location_2 = "/tmp/optimized2_#{System.monotonic_time()}.cbz"

      File.touch!(optimized_location_1)
      File.touch!(optimized_location_2)

      on_exit(fn ->
        File.rm!(optimized_location_1)
        File.rm!(optimized_location_2)
      end)

      # Create first optimization
      {:ok, optimized1} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location_1
        })

      # Try to optimize the optimized version
      {:error, changeset} =
        Comics.create_optimized_comic(optimized1, %{
          resource_location: optimized_location_2
        })

      assert "Comic cannot be both original and optimized" in errors_on(changeset).original_id
    end

    test "cannot create second optimized version of same original" do
      original = insert(:comic)
      optimized_location_1 = "/tmp/optimized1_#{System.monotonic_time()}.cbz"
      optimized_location_2 = "/tmp/optimized2_#{System.monotonic_time()}.cbz"

      File.touch!(optimized_location_1)
      File.touch!(optimized_location_2)

      on_exit(fn ->
        File.rm!(optimized_location_1)
        File.rm!(optimized_location_2)
      end)

      # Create first optimization
      {:ok, _optimized1} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location_1
        })

      # Try to create second optimization
      {:error, changeset} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location_2
        })

      assert "Original comic already has an optimized version" in errors_on(changeset).original_id
    end

    test "get_preferred_comic/2 returns optimized version by default" do
      original = insert(:comic)
      optimized_location = "/tmp/optimized_#{System.monotonic_time()}.cbz"

      File.touch!(optimized_location)
      on_exit(fn -> File.rm!(optimized_location) end)

      {:ok, optimized} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location
        })

      # Should return optimized version by default
      {:ok, preferred} = Comics.get_preferred_comic(original.id)
      assert preferred.id == optimized.id

      # Should return original when specifically requested
      {:ok, original_comic} = Comics.get_preferred_comic(original.id, prefer_optimized: false)
      assert original_comic.id == original.id
    end

    test "get_preferred_comic/2 returns original when no optimization exists" do
      original = insert(:comic)

      {:ok, preferred} = Comics.get_preferred_comic(original.id)
      assert preferred.id == original.id
    end

    test "revert_optimization/1 from optimized comic deletes optimized and clears original link" do
      original = insert(:comic)
      optimized_location = "/tmp/optimized_#{System.monotonic_time()}.cbz"

      File.touch!(optimized_location)
      on_exit(fn -> File.rm!(optimized_location) end)

      {:ok, optimized} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location
        })

      # Revert from optimized comic
      {:ok, reverted_original} = Comics.revert_optimization(optimized.id)

      # Optimized should be deleted
      assert {:error, :not_found} = Comics.get_comic(optimized.id)

      # Original should have optimized_id cleared
      assert reverted_original.id == original.id
      assert is_nil(reverted_original.optimized_id)
    end

    test "revert_optimization/1 from original comic clears optimization link" do
      original = insert(:comic)
      optimized_location = "/tmp/optimized_#{System.monotonic_time()}.cbz"

      File.touch!(optimized_location)
      on_exit(fn -> File.rm!(optimized_location) end)

      {:ok, optimized} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location
        })

      # Revert from original comic
      {:ok, reverted_original} = Comics.revert_optimization(original.id)

      # Optimized should still exist but not linked
      {:ok, orphaned_optimized} = Comics.get_comic(optimized.id)
      assert is_nil(orphaned_optimized.original_id)

      # Original should have optimized_id cleared
      assert reverted_original.id == original.id
      assert is_nil(reverted_original.optimized_id)
    end

    test "revert_optimization/1 fails for comic with no optimization" do
      original = insert(:comic)

      {:error, message} = Comics.revert_optimization(original.id)
      assert message == "Comic has no optimization to revert"
    end

    test "list_comics/1 with prefer_optimized filters original comics" do
      original1 = insert(:comic)
      original2 = insert(:comic)
      original3 = insert(:comic)

      optimized_location = "/tmp/optimized_#{System.monotonic_time()}.cbz"
      optimized_location2 = "/tmp/optimized2_#{System.monotonic_time()}.cbz"
      File.touch!(optimized_location)
      File.touch!(optimized_location2)

      on_exit(fn ->
        File.rm!(optimized_location)
        File.rm!(optimized_location2)
      end)

      # Create optimizations for first two
      {:ok, optimized1} =
        Comics.create_optimized_comic(original1, %{
          resource_location: optimized_location
        })

      {:ok, _optimized2} =
        Comics.create_optimized_comic(original2, %{
          resource_location: optimized_location2
        })

      all_comics = Comics.list_comics()
      comic_ids = Enum.map(all_comics, & &1.id) |> MapSet.new()
      assert MapSet.member?(comic_ids, original1.id)
      assert MapSet.member?(comic_ids, original2.id)
      assert MapSet.member?(comic_ids, original3.id)
      assert MapSet.member?(comic_ids, optimized1.id)

      # With filter - should hide originals that have optimizations
      filtered_comics = Comics.list_comics(prefer_optimized: true)
      filtered_ids = Enum.map(filtered_comics, & &1.id) |> MapSet.new()
      # Hidden
      refute MapSet.member?(filtered_ids, original1.id)
      # Hidden
      refute MapSet.member?(filtered_ids, original2.id)
      # Visible (no optimization)
      assert MapSet.member?(filtered_ids, original3.id)
      # Visible (optimized version)
      assert MapSet.member?(filtered_ids, optimized1.id)
    end

    test "clone_attrs/2 correctly clones cloneable attributes" do
      original = insert(:comic)
      # Update the comic with specific test values after creation
      {:ok, original} =
        Comics.update_comic(original, %{
          title: "Test Title",
          author: "Test Author",
          description: "Test Description"
        })

      cloned_attrs = Comic.clone_attrs(original)

      # Should include cloneable attributes
      assert cloned_attrs.title == "Test Title"
      assert cloned_attrs.author == "Test Author"
      assert cloned_attrs.description == "Test Description"
      assert cloned_attrs.original_id == original.id

      # Should NOT include non-cloneable attributes
      refute Map.has_key?(cloned_attrs, :resource_location)
      refute Map.has_key?(cloned_attrs, :byte_size)
      refute Map.has_key?(cloned_attrs, :id)
      refute Map.has_key?(cloned_attrs, :inserted_at)
      refute Map.has_key?(cloned_attrs, :updated_at)
      refute Map.has_key?(cloned_attrs, :optimized_id)
    end

    test "clone_attrs/2 with overrides applies custom values" do
      original = insert(:comic, title: "Original", description: "Original desc")

      cloned_attrs =
        Comic.clone_attrs(original, %{
          description: "New description",
          resource_location: "/new/path"
        })

      # Cloned
      assert cloned_attrs.title == "Original"
      # Overridden
      assert cloned_attrs.description == "New description"
      # Added
      assert cloned_attrs.resource_location == "/new/path"
      assert cloned_attrs.original_id == original.id
    end

    test "changeset validation prevents optimization chains" do
      original = insert(:comic)

      # Try to create a comic that's both original and optimized
      attrs = %{
        title: "Test",
        resource_location: "/tmp/test.cbz",
        original_id: original.id,
        # Invalid!
        optimized_id: original.id
      }

      File.touch!("/tmp/test.cbz")
      on_exit(fn -> File.rm!("/tmp/test.cbz") end)

      changeset = Comic.changeset(%Comic{}, attrs)
      refute changeset.valid?
      assert "Comic cannot be both original and optimized" in errors_on(changeset).original_id
    end

    test "database constraint prevents optimization chains" do
      original = insert(:comic)
      optimized_location = "/tmp/optimized_#{System.monotonic_time()}.cbz"

      File.touch!(optimized_location)
      on_exit(fn -> File.rm!(optimized_location) end)

      {:ok, optimized} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location
        })

      # Try to directly update optimized comic to have an optimized_id (bypassing changeset validation)
      assert_raise Postgrex.Error, ~r/no_optimization_chain/, fn ->
        Repo.update_all(
          from(c in Comic, where: c.id == ^optimized.id),
          set: [optimized_id: original.id]
        )
      end
    end

    test "preloading optimization relationships" do
      original = insert(:comic)
      optimized_location = "/tmp/optimized_#{System.monotonic_time()}.cbz"

      File.touch!(optimized_location)
      on_exit(fn -> File.rm!(optimized_location) end)

      {:ok, optimized} =
        Comics.create_optimized_comic(original, %{
          resource_location: optimized_location
        })

      # Test preloading from original
      {:ok, original_with_preload} = Comics.get_comic(original.id, preload: [:optimized_comic])
      assert original_with_preload.optimized_comic.id == optimized.id

      # Test preloading from optimized
      {:ok, optimized_with_preload} = Comics.get_comic(optimized.id, preload: [:original_comic])
      assert optimized_with_preload.original_comic.id == original.id
    end
  end
end
