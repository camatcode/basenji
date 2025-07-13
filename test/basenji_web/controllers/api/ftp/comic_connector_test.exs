defmodule BasenjiWeb.FTP.ComicConnectorTest do
  use Basenji.DataCase

  alias Basenji.Collections
  alias Basenji.Comics
  alias BasenjiWeb.FTP.ComicConnector

  @moduletag :capture_log

  doctest ComicConnector

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

      %{comics: comics, collections: collections}
    end

    test "list", %{} do
      comics = Comics.list_comics(prefer_optimized: true)
      # /
      {:ok, [%{file_name: "comics/"}, %{file_name: "collections/"}]} =
        ComicConnector.get_directory_contents("/", %{})

      # /comics
      {:ok, [%{file_name: "by-id/"}, %{file_name: "by-title/"}]} =
        ComicConnector.get_directory_contents("/comics", %{})

      # /comics/by-id
      {:ok, comics_by_id} = ComicConnector.get_directory_contents("/comics/by-id", %{})
      ids = comics_by_id |> Enum.map(&Path.rootname(&1.file_name))

      assert ids == Enum.map(comics, & &1.id)

      # /comics/by-title
      {:ok, comics_by_title} = ComicConnector.get_directory_contents("/comics/by-title", %{})
      titles = comics_by_title |> Enum.map(&Path.rootname(&1.file_name))

      Enum.each(titles, fn title ->
        assert [_comic] = Enum.filter(comics, fn comic -> comic.title == title end)
      end)

      # /collections
      {:ok, [%{file_name: "by-title/"}]} = ComicConnector.get_directory_contents("/collections", %{})

      # /collections/by-title
      {:ok, collections_by_title} = ComicConnector.get_directory_contents("/collections/by-title", %{})
      titles = collections_by_title |> Enum.map(&Path.rootname(&1.file_name))

      Enum.each(titles, fn title ->
        assert [_collection] = Collections.list_collections(title: title)
      end)

      #  # /collections/by-title/{title}/
      Enum.each(titles, fn title ->
        {:ok, results} = ComicConnector.get_directory_contents("/collections/by-title/#{title}", %{})
        directories = Enum.filter(results, fn result -> result.type == :directory end)

        #  # /collections/by-title/{title}/{title or comics}
        Enum.each(directories, fn directory ->
          {:ok, _} =
            ComicConnector.get_directory_contents("/collections/by-title/#{title}/#{directory.file_name}", %{})
        end)
      end)
    end

    test "download", %{} do
      # /comics/by-title/...
      comics = Comics.list_comics(prefer_optimized: true)

      Enum.each(comics, fn comic ->
        {:ok, %File.Stream{}} =
          ComicConnector.get_content("/comics/by-title/#{comic.title}/#{comic.title}.#{comic.format}", %{})
      end)

      # /comics/by-id/....
      Enum.each(comics, fn comic ->
        {:ok, %File.Stream{}} = ComicConnector.get_content("/comics/by-id/#{comic.id}/#{comic.id}.#{comic.format}", %{})
      end)

      # /collections/by-title/{parent}/{some collection}/comics/by-id/...
      [parent] = Collections.list_collections(parent_id: :none, preload: [:comics])
      children = Collections.list_collections(parent_id: parent.id, preload: [:comics])

      Enum.each(children, fn child ->
        Enum.each(child.comics, fn comic ->
          {:ok, %File.Stream{}} =
            ComicConnector.get_content(
              "/collections/by-title/#{parent.title}/#{child.title}/comics/by-id/#{comic.id}/#{comic.id}.#{comic.format}",
              %{}
            )
        end)
      end)

      # /collections/by-title/{parent}/{some collection}/comics/by-title/...
      Enum.each(children, fn child ->
        Enum.each(child.comics, fn comic ->
          {:ok, %File.Stream{}} =
            ComicConnector.get_content(
              "/collections/by-title/#{parent.title}/#{child.title}/comics/by-title/#{comic.title}/#{comic.title}.#{comic.format}",
              %{}
            )
        end)
      end)
    end

    test "pages" do
      comics = Comics.list_comics(prefer_optimized: true)

      Enum.each(comics, fn comic ->
        {:ok, bytes} = ComicConnector.get_content("/comics/by-id/#{comic.id}/pages/01.jpg", %{})
        assert byte_size(bytes) > 0
      end)
    end
  end

  test "get_cwd" do
    cwd = "/"
    connector_state = %{current_working_directory: cwd}
    ^cwd = ComicConnector.get_working_directory(connector_state)

    cwd = "/comics"
    connector_state = %{current_working_directory: cwd}
    ^cwd = ComicConnector.get_working_directory(connector_state)

    cwd = "/comics/by-id/"
    connector_state = %{current_working_directory: cwd}
    ^cwd = ComicConnector.get_working_directory(connector_state)

    cwd = "/comics/invalid"
    connector_state = %{current_working_directory: cwd}
    assert "/" == ComicConnector.get_working_directory(connector_state)
  end

  test "directory_exists?" do
    assert ComicConnector.directory_exists?("/", %{})
    assert ComicConnector.directory_exists?("/comics", %{})
    assert ComicConnector.directory_exists?("/collections", %{})
    refute ComicConnector.directory_exists?("/invalid", %{})
  end
end
