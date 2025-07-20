defmodule BasenjiWeb.FTP.ComicConnectorTest do
  use Basenji.DataCase

  alias Basenji.Collections
  alias Basenji.Comics
  alias BasenjiWeb.FTP.ComicConnector

  @moduletag :capture_log

  doctest ComicConnector

  describe "working directory management" do
    test "get_working_directory returns valid directory" do
      cwd = "/"
      connector_state = %{current_working_directory: cwd}
      assert "/" == ComicConnector.get_working_directory(connector_state)

      cwd = "/comics"
      connector_state = %{current_working_directory: cwd}
      assert "/comics" == ComicConnector.get_working_directory(connector_state)

      cwd = "/comics/by-id/"
      connector_state = %{current_working_directory: cwd}
      assert "/comics/by-id/" == ComicConnector.get_working_directory(connector_state)
    end

    test "get_working_directory falls back to root for invalid paths" do
      cwd = "/comics/invalid"
      connector_state = %{current_working_directory: cwd}
      assert "/" == ComicConnector.get_working_directory(connector_state)

      cwd = "/invalid/path"
      connector_state = %{current_working_directory: cwd}
      assert "/" == ComicConnector.get_working_directory(connector_state)
    end
  end

  describe "directory existence checks" do
    test "directory_exists? validates known paths" do
      assert ComicConnector.directory_exists?("/", %{})
      assert ComicConnector.directory_exists?("/comics", %{})
      assert ComicConnector.directory_exists?("/comics/by-id", %{})
      assert ComicConnector.directory_exists?("/comics/by-title", %{})
      assert ComicConnector.directory_exists?("/collections", %{})
      assert ComicConnector.directory_exists?("/collections/by-title", %{})
    end

    test "directory_exists? rejects invalid paths" do
      refute ComicConnector.directory_exists?("/invalid", %{})
      refute ComicConnector.directory_exists?("/comics/invalid", %{})
      refute ComicConnector.directory_exists?("/collections/invalid", %{})
      # Note: Empty string is normalized to "/" by PathValidator, so it returns true
      refute ComicConnector.directory_exists?("invalid", %{})
    end

    test "directory_exists? validates comic-specific paths" do
      comic = insert(:comic)

      assert ComicConnector.directory_exists?("/comics/by-id/#{comic.id}", %{})
      assert ComicConnector.directory_exists?("/comics/by-title/#{comic.title}", %{})
      assert ComicConnector.directory_exists?("/comics/by-id/#{comic.id}/pages", %{})
      assert ComicConnector.directory_exists?("/comics/by-id/#{comic.id}/preview", %{})
    end

    test "directory_exists? validates collection-specific paths" do
      parent = insert(:collection, parent: nil)
      child = insert(:collection, parent: parent)

      assert ComicConnector.directory_exists?("/collections/by-title/#{parent.title}", %{})
      assert ComicConnector.directory_exists?("/collections/by-title/#{parent.title}/#{child.title}", %{})
      assert ComicConnector.directory_exists?("/collections/by-title/#{parent.title}/#{child.title}/comics", %{})
      assert ComicConnector.directory_exists?("/collections/by-title/#{parent.title}/#{child.title}/comics/by-id", %{})

      assert ComicConnector.directory_exists?(
               "/collections/by-title/#{parent.title}/#{child.title}/comics/by-title",
               %{}
             )
    end
  end

  describe "get_content_info behavior" do
    test "returns content info for comic by ID" do
      comic = insert(:comic, title: "Test Comic", format: :cbz)

      {:ok, info} = ComicConnector.get_content_info("/comics/by-id/#{comic.id}/#{comic.id}.cbz", %{})

      assert info.file_name == "#{comic.id}.cbz"
      assert info.type == :file
      assert info.size == comic.byte_size
      assert info.access == :read
      assert info.modified_datetime == comic.updated_at
    end

    test "returns content info for comic by title" do
      comic = insert(:comic, format: :pdf)
      comic_filename = Path.basename(comic.resource_location)

      {:ok, info} = ComicConnector.get_content_info("/comics/by-title/#{comic.title}/#{comic_filename}", %{})
      assert info.type == :file
      assert info.access == :read
    end

    test "returns error for non-existent comic" do
      fake_id = Ecto.UUID.generate()
      assert {:error, _} = ComicConnector.get_content_info("/comics/by-id/#{fake_id}/#{fake_id}.cbz", %{})
    end

    test "returns error for invalid path" do
      assert {:error, _} = ComicConnector.get_content_info("/invalid/path", %{})
    end
  end

  describe "get_content behavior" do
    test "returns file stream for comic by ID" do
      comic = insert(:comic)

      {:ok, stream} = ComicConnector.get_content("/comics/by-id/#{comic.id}/#{comic.id}.#{comic.format}", %{})

      assert %File.Stream{} = stream
      assert stream.path == comic.resource_location
    end

    test "returns file stream for comic by title" do
      comic = insert(:comic)
      comic_filename = Path.basename(comic.resource_location)

      {:ok, stream} = ComicConnector.get_content("/comics/by-title/#{comic.title}/#{comic_filename}", %{})

      assert %File.Stream{} = stream
      assert stream.path == comic.resource_location
    end

    test "returns page content for comic pages" do
      comic = insert(:comic, page_count: 10)

      {:ok, bytes} = ComicConnector.get_content("/comics/by-id/#{comic.id}/pages/01.jpg", %{})

      assert is_binary(bytes)
      assert byte_size(bytes) > 0
    end

    test "returns page content by title" do
      comic = insert(:comic, title: "Page Test", page_count: 5)

      {:ok, bytes} = ComicConnector.get_content("/comics/by-title/#{comic.title}/pages/01.jpg", %{})

      assert is_binary(bytes)
      assert byte_size(bytes) > 0
    end

    test "returns preview content when available" do
      %{resource_location: loc} = build(:comic)
      {:ok, comic} = Comics.create_comic(%{resource_location: loc})

      TestHelper.drain_queues([:comic, :comic_low])
      {:ok, preview_result} = ComicConnector.get_content("/comics/by-id/#{comic.id}/preview/preview.jpg", %{})

      assert byte_size(preview_result) > 0
    end

    test "returns error for preview when not available" do
      comic = insert(:comic)

      assert {:error, :not_found} = ComicConnector.get_content("/comics/by-id/#{comic.id}/preview/preview.jpg", %{})
    end

    test "returns file stream for comics in collections" do
      parent = insert(:collection, parent: nil)
      child = insert(:collection, parent: parent)
      comic = insert(:comic)
      Collections.add_to_collection(child, comic)

      {:ok, stream} =
        ComicConnector.get_content(
          "/collections/by-title/#{parent.title}/#{child.title}/comics/by-id/#{comic.id}/#{comic.id}.#{comic.format}",
          %{}
        )

      assert %File.Stream{} = stream
      assert stream.path == comic.resource_location
    end

    test "returns error for non-existent content" do
      assert {:error, :invalid_path} = ComicConnector.get_content("/invalid/path", %{})

      fake_id = Ecto.UUID.generate()
      assert {:error, _} = ComicConnector.get_content("/comics/by-id/#{fake_id}/fake.cbz", %{})
    end

    test "returns error for mismatched comic file path" do
      comic = insert(:comic)
      wrong_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ComicConnector.get_content("/comics/by-id/#{comic.id}/#{wrong_id}.cbz", %{})
    end
  end

  describe "read-only operations" do
    test "make_directory returns success without changes" do
      state = %{current_working_directory: "/"}

      assert {:ok, ^state} = ComicConnector.make_directory("/test", state)
    end

    test "delete_directory returns success without changes" do
      state = %{current_working_directory: "/"}

      assert {:ok, ^state} = ComicConnector.delete_directory("/test", state)
    end

    test "delete_file returns success without changes" do
      state = %{current_working_directory: "/"}

      assert {:ok, ^state} = ComicConnector.delete_file("/test.txt", state)
    end

    test "create_write_func returns no-op function" do
      state = %{current_working_directory: "/"}

      write_func = ComicConnector.create_write_func("/test.txt", state)

      assert is_function(write_func, 1)
      assert {:ok, ^state} = write_func.("test data")
    end
  end

  describe "error handling" do
    test "handles malformed paths gracefully" do
      malformed_paths = [
        "//double//slash",
        "/comics/../escape",
        "/comics/by-id/not-a-uuid",
        "/collections/by-title//empty"
      ]

      Enum.each(malformed_paths, fn path ->
        {:error, _} = ComicConnector.get_directory_contents(path, %{})

        assert {:error, _} = ComicConnector.get_content_info(path, %{})
        assert {:error, _} = ComicConnector.get_content(path, %{})
      end)
    end

    test "handles database errors gracefully" do
      fake_uuid = Ecto.UUID.generate()

      {:error, :not_found} = ComicConnector.get_directory_contents("/comics/by-id/#{fake_uuid}", %{})

      assert {:error, _} = ComicConnector.get_content("/comics/by-id/#{fake_uuid}/#{fake_uuid}.cbz", %{})
    end
  end

  describe "complex operations" do
    setup do
      parent = insert(:collection, parent: nil)
      collections = insert_list(10, :collection, parent: parent)
      comics = insert_list(20, :comic)

      Enum.each(comics, fn comic ->
        num_collections_member = Enum.random(1..10)
        member_collections = 0..num_collections_member |> Enum.map(fn _ -> Enum.random(collections) end)

        member_collections
        |> Enum.each(fn collection ->
          Collections.add_to_collection(collection, comic)
        end)
      end)

      %{comics: comics, collections: collections, parent: parent}
    end

    test "directory listing consistency", %{comics: comics} do
      # Root directory structure
      {:ok, [%{file_name: "comics/"}, %{file_name: "collections/"}]} =
        ComicConnector.get_directory_contents("/", %{})

      # Comics directory structure
      {:ok, [%{file_name: "by-id/"}, %{file_name: "by-title/"}]} =
        ComicConnector.get_directory_contents("/comics", %{})

      # Verify all comics appear in by-id listing
      {:ok, comics_by_id} = ComicConnector.get_directory_contents("/comics/by-id", %{})
      ids = comics_by_id |> Enum.map(&String.replace(&1.file_name, "/", ""))
      assert length(ids) == length(comics)
      assert Enum.all?(comics, fn comic -> comic.id in ids end)

      # Verify all comics appear in by-title listing
      {:ok, comics_by_title} = ComicConnector.get_directory_contents("/comics/by-title", %{})
      titles = comics_by_title |> Enum.map(&String.replace(&1.file_name, "/", ""))

      Enum.each(titles, fn title ->
        assert [_comic] = Enum.filter(comics, fn comic -> comic.title == title end)
      end)
    end

    test "collection navigation integrity", %{parent: parent, collections: collections} do
      # Collections root structure
      {:ok, [%{file_name: "by-title/"}]} = ComicConnector.get_directory_contents("/collections", %{})

      # Parent collections listing
      {:ok, collections_by_title} = ComicConnector.get_directory_contents("/collections/by-title", %{})
      parent_titles = collections_by_title |> Enum.map(& &1.file_name)

      assert parent.title in parent_titles

      # Child collections under parent
      {:ok, child_contents} = ComicConnector.get_directory_contents("/collections/by-title/#{parent.title}", %{})
      child_dirs = Enum.filter(child_contents, fn item -> item.type == :directory and item.file_name != "comics/" end)
      child_titles = Enum.map(child_dirs, & &1.file_name)

      Enum.each(collections, fn collection ->
        assert collection.title in child_titles
      end)

      # Verify comics directory exists in each child collection
      Enum.each(collections, fn collection ->
        {:ok, contents} =
          ComicConnector.get_directory_contents("/collections/by-title/#{parent.title}/#{collection.title}", %{})

        assert Enum.any?(contents, fn item -> item.file_name == "comics/" and item.type == :directory end)

        # Verify comics subdirectories
        {:ok, comics_contents} =
          ComicConnector.get_directory_contents("/collections/by-title/#{parent.title}/#{collection.title}/comics", %{})

        comic_dirs = Enum.map(comics_contents, & &1.file_name)
        assert "by-id/" in comic_dirs
        assert "by-title/" in comic_dirs
      end)
    end

    test "file download paths work consistently", %{comics: comics, collections: collections, parent: parent} do
      # Test direct comic downloads by ID and title
      Enum.take(comics, 3)
      |> Enum.each(fn comic ->
        # By ID
        {:ok, %File.Stream{}} =
          ComicConnector.get_content("/comics/by-id/#{comic.id}/#{comic.id}.#{comic.format}", %{})

        # By title
        {:ok, %File.Stream{}} =
          ComicConnector.get_content("/comics/by-title/#{comic.title}/#{comic.title}.#{comic.format}", %{})
      end)

      # Test downloads through collections
      Enum.take(collections, 2)
      |> Enum.each(fn collection ->
        # Get comics from this collection
        {:ok, collection_with_comics} = Collections.get_collection(collection.id, preload: [:comics])

        Enum.take(collection_with_comics.comics, 2)
        |> Enum.each(fn comic ->
          # Via collection by-id path
          {:ok, %File.Stream{}} =
            ComicConnector.get_content(
              "/collections/by-title/#{parent.title}/#{collection.title}/comics/by-id/#{comic.id}/#{comic.id}.#{comic.format}",
              %{}
            )

          # Via collection by-title path
          {:ok, %File.Stream{}} =
            ComicConnector.get_content(
              "/collections/by-title/#{parent.title}/#{collection.title}/comics/by-title/#{comic.title}/#{comic.title}.#{comic.format}",
              %{}
            )
        end)
      end)
    end

    test "page extraction works for multiple access patterns", %{comics: comics} do
      comics_with_pages = Enum.filter(comics, fn comic -> comic.page_count > 0 end)

      Enum.take(comics_with_pages, 3)
      |> Enum.each(fn comic ->
        # Test page access by ID
        {:ok, bytes} = ComicConnector.get_content("/comics/by-id/#{comic.id}/pages/01.jpg", %{})
        assert byte_size(bytes) > 0

        # Test page access by title
        {:ok, bytes} = ComicConnector.get_content("/comics/by-title/#{comic.title}/pages/01.jpg", %{})
        assert byte_size(bytes) > 0

        # Test that page directory lists correct number of pages
        {:ok, page_list} = ComicConnector.get_directory_contents("/comics/by-id/#{comic.id}/pages", %{})
        assert length(page_list) == comic.page_count

        # Verify page numbering format
        page_files = Enum.map(page_list, & &1.file_name)
        padding = String.length("#{comic.page_count}")

        Enum.with_index(page_files, 1)
        |> Enum.each(fn {page_file, index} ->
          expected_name = "#{String.pad_leading("#{index}", padding, "0")}.jpg"
          assert page_file == expected_name
        end)
      end)
    end
  end
end
