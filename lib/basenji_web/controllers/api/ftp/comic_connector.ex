defmodule BasenjiWeb.FTP.ComicConnector do
  @moduledoc false
  @behaviour ExFTP.StorageConnector

  alias Basenji.Collections
  alias Basenji.Comics
  alias BasenjiWeb.FTP.PathValidator
  alias ExFTP.StorageConnector

  @impl StorageConnector
  @spec get_working_directory(connector_state :: StorageConnector.connector_state()) ::
          String.t()
  def get_working_directory(%{current_working_directory: cwd} = _connector_state) do
    if PathValidator.valid_root_directory?(cwd) do
      cwd
    else
      "/"
    end
  end

  @impl StorageConnector
  @spec directory_exists?(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: boolean
  def directory_exists?(path, _connector_state) do
    PathValidator.parse_path(path)
    |> case do
      {:ok, _path_info} -> true
      _ -> false
    end
  end

  @impl StorageConnector
  @spec get_directory_contents(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) ::
          {:ok, [StorageConnector.content_info()]} | {:error, term()}
  def get_directory_contents(path, _connector_state) do
    with {:ok, path_info} <- PathValidator.parse_path(path) do
      build_directory_contents(path_info)
      |> case do
        {:error, _} = e -> e
        other -> {:ok, other}
      end
    end
  end

  @impl StorageConnector
  @spec get_content_info(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) ::
          {:ok, StorageConnector.content_info()} | {:error, term()}
  def get_content_info(path, _connector_state) do
    with {:ok, path_info} <- PathValidator.parse_path(path) do
      get_content_info(path_info)
      |> case do
        m when is_map(m) -> {:ok, m}
        other -> other
      end
    end
  end

  @impl StorageConnector
  @spec get_content(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, any()} | {:error, term()}
  def get_content(path, _connector_state) do
    with {:ok, path_info} <- PathValidator.parse_path(path) do
      get_content(path_info)
    end
  end

  # Page files
  defp get_content(%{comic_id: comic_id, subpath: "pages/" <> page_file}) do
    with {:ok, comic} <- Comics.get_comic(comic_id) do
      idx = Path.rootname(page_file) |> String.to_integer()
      {:ok, bytes, _mime} = Comics.get_page(comic, idx)
      {:ok, bytes}
    end
  end

  defp get_content(%{comic_title: comic_title, subpath: "pages/" <> page_file}) do
    with {:ok, comic} <- get_comic_from_title(comic_title) do
      idx = Path.rootname(page_file) |> String.to_integer()
      {:ok, bytes, _mime} = Comics.get_page(comic, idx)
      {:ok, bytes}
    end
  end

  defp get_content(%{comic_id: comic_id, subpath: "preview/" <> _preview_file}) do
    with {:ok, comic} <- Comics.get_comic(comic_id) do
      Comics.get_image_preview(comic)
      |> case do
        {:ok, bytes} -> {:ok, bytes}
        _ -> {:error, :not_found}
      end
    end
  end

  defp get_content(%{comic_title: comic_title, subpath: "preview/" <> _preview_file}) do
    with {:ok, comic} <- get_comic_from_title(comic_title) do
      Comics.get_image_preview(comic)
      |> case do
        {:ok, bytes} -> {:ok, bytes}
        _ -> {:error, :not_found}
      end
    end
  end

  defp get_content(%{comic_id: comic_id, subpath: subpath}) when is_bitstring(subpath) do
    if String.starts_with?(subpath, comic_id) do
      with {:ok, comic} <- Comics.get_comic(comic_id) do
        {:ok, File.stream!(comic.resource_location)}
      end
    else
      {:error, :not_found}
    end
  end

  defp get_content(%{comic_title: comic_title, subpath: _subpath}) do
    with {:ok, comic} <- get_comic_from_title(comic_title) do
      {:ok, File.stream!(comic.resource_location)}
    end
  end

  defp get_content(_) do
    {:error, :not_found}
  end

  # Pass-throughs - this connector is read only.
  @impl StorageConnector
  @spec make_directory(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
  def make_directory(_path, connector_state) do
    {:ok, connector_state}
  end

  @impl StorageConnector
  @spec delete_directory(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
  def delete_directory(_path, connector_state) do
    {:ok, connector_state}
  end

  @impl StorageConnector
  @spec delete_file(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
  def delete_file(_path, connector_state) do
    {:ok, connector_state}
  end

  @impl StorageConnector
  @spec create_write_func(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state(),
          opts :: list()
        ) :: function()
  def create_write_func(_path, connector_state, _opts \\ []) do
    fn _stream ->
      {:ok, connector_state}
    end
  end

  defp get_content_info(%{comic_id: comic_id}) do
    with {:ok, comic} <- Comics.get_comic(comic_id) do
      comic_to_content_info(comic)
    end
  end

  defp get_content_info(%{comic_title: title}) do
    with [found] <- Comics.list_comics(title: title, prefer_optimized: true) do
      comic_to_content_info(found, true)
    end
  end

  defp get_content_info(_), do: {:error, :not_found}

  defp to_content_info(path, :directory) do
    %{
      file_name: Path.join(path, "") <> "/",
      modified_datetime: DateTime.from_unix!(0),
      size: 4096,
      access: :read,
      type: :directory
    }
  end

  defp build_directory_contents(%{path: "/"}) do
    ["comics", "collections"]
    |> Enum.map(&to_content_info(&1, :directory))
  end

  defp build_directory_contents(%{path: "/comics", subpath: nil}) do
    ["by-id", "by-title"]
    |> Enum.map(&to_content_info(&1, :directory))
  end

  defp build_directory_contents(%{path: "/collections", subpath: nil}) do
    ["by-title"]
    |> Enum.map(&to_content_info(&1, :directory))
  end

  defp build_directory_contents(%{comic_id: comic_id, subpath: nil}) do
    with {:ok, comic} <- Comics.get_comic(comic_id) do
      format = comic.format || "unknown"

      comic_file = %{
        file_name: "#{comic_id}.#{format}",
        type: :file,
        size: comic.byte_size,
        access: :read,
        modified_datetime: comic.updated_at
      }

      dirs = ["pages", "preview"] |> Enum.map(&to_content_info(&1, :directory))
      [comic_file | dirs]
    end
  end

  defp build_directory_contents(%{comic_title: comic_title, subpath: nil}) do
    with {:ok, comic} <- get_comic_from_title(comic_title) do
      format = comic.format || "unknown"

      comic_file = %{
        file_name: "#{comic_title}.#{format}",
        type: :file,
        size: comic.byte_size,
        access: :read,
        modified_datetime: comic.updated_at
      }

      dirs = ["pages", "preview"] |> Enum.map(&to_content_info(&1, :directory))
      [comic_file | dirs]
    end
  end

  defp build_directory_contents(%{comic_id: comic_id, subpath: "pages"}) do
    with {:ok, comic} <- Comics.get_comic(comic_id) do
      padding = String.length("#{comic.page_count}")

      1..comic.page_count
      |> Enum.map(&to_image_content_info(String.pad_leading("#{&1}", padding, "0"), "jpg"))
    end
  end

  defp build_directory_contents(%{comic_title: comic_title, subpath: "pages"}) do
    with {:ok, comic} <- get_comic_from_title(comic_title) do
      padding = String.length("#{comic.page_count}")

      1..comic.page_count
      |> Enum.map(&to_image_content_info(String.pad_leading("#{&1}", padding, "0"), "jpg"))
    end
  end

  defp build_directory_contents(%{comic_id: comic_id, subpath: "preview"}) do
    with {:ok, comic} <- Comics.get_comic(comic_id) do
      if comic.image_preview do
        [to_image_content_info("preview", "jpg")]
      else
        []
      end
    end
  end

  defp build_directory_contents(%{comic_title: comic_title, subpath: "preview"}) do
    with {:ok, comic} <- get_comic_from_title(comic_title) do
      if comic.image_preview do
        [to_image_content_info("preview", "jpg")]
      else
        []
      end
    end
  end

  defp build_directory_contents(%{path: "/comics/by-id", subpath: nil}) do
    Comics.list_comics(prefer_optimized: true)
    |> Enum.map(&comic_id_to_directory_info/1)
  end

  defp build_directory_contents(%{path: "/comics/by-title", subpath: nil}) do
    Comics.list_comics(prefer_optimized: true, order_by: :title)
    |> Enum.filter(& &1.title)
    |> Enum.map(&comic_title_to_directory_info/1)
  end

  defp build_directory_contents(%{path: "/collections/by-title", subpath: nil}) do
    Collections.list_collections(parent_id: :none)
    |> Enum.map(&collection_to_content_info/1)
  end

  defp build_directory_contents(%{collection_title: _collection_title, subpath: "comics"}) do
    ["by-id", "by-title"]
    |> Enum.map(&to_content_info(&1, :directory))
  end

  defp build_directory_contents(%{collection_title: collection_title, subpath: nil}) do
    with {:ok, collection} <- get_collection_by_title(collection_title) do
      child_collections = Collections.list_collections(parent_id: collection.id, order_by: :title)

      comics_dir = [to_content_info("comics", :directory)]
      collection_dirs = Enum.map(child_collections, &collection_to_content_info/1)

      collection_dirs ++ comics_dir
    end
  end

  defp build_directory_contents(%{collection_title: collection_title, subpath: "comics/by-id"}) do
    with {:ok, collection} <- get_collection_by_title(collection_title) do
      collection.comics
      |> Enum.map(&comic_id_to_directory_info/1)
    end
  end

  defp build_directory_contents(%{collection_title: collection_title, subpath: "comics/by-title"}) do
    with {:ok, collection} <- get_collection_by_title(collection_title) do
      collection.comics
      |> Enum.filter(& &1.title)
      |> Enum.sort_by(& &1.title)
      |> Enum.map(&comic_title_to_directory_info/1)
    end
  end

  defp build_directory_contents(_path_info), do: []

  defp comic_to_content_info(comic, title? \\ false) do
    format = comic.format || "unknown"
    file_name = if title?, do: "#{Path.basename(comic.resource_location)}", else: "#{comic.id}.#{format}"

    %{
      file_name: file_name,
      type: :file,
      size: comic.byte_size,
      access: :read,
      modified_datetime: comic.updated_at
    }
  end

  defp collection_to_content_info(collection) do
    %{
      file_name: collection.title,
      type: :directory,
      size: 4096,
      access: :read,
      modified_datetime: collection.updated_at
    }
  end

  defp to_image_content_info(idx, ext) do
    %{
      file_name: "#{idx}.#{ext}",
      type: :file,
      size: 1,
      access: :read,
      modified_datetime: DateTime.from_unix!(0)
    }
  end

  defp get_collection_by_title(collection_title) do
    Collections.list_collections(title: collection_title, preload: [:comics])
    |> case do
      [found] -> {:ok, found}
      _ -> {:error, :not_found}
    end
  end

  defp get_comic_from_title(comic_title) when not is_nil(comic_title) do
    Comics.list_comics(title: comic_title)
    |> case do
      [found] -> {:ok, found}
      _ -> {:error, :not_found}
    end
  end

  defp comic_id_to_directory_info(comic) do
    %{
      file_name: "#{comic.id}/",
      type: :directory,
      size: 4096,
      access: :read,
      modified_datetime: comic.updated_at
    }
  end

  defp comic_title_to_directory_info(comic) do
    %{
      file_name: "#{comic.title}/",
      type: :directory,
      size: 4096,
      access: :read,
      modified_datetime: comic.updated_at
    }
  end
end
