defmodule Basenji.Library do
  @moduledoc """
  Handles comic library operations including scanning directories for comics,
  generating thumbnails, and managing comic metadata.
  """

  alias Basenji.Reader

  require Logger

  @comic_extensions [".cbz", ".cbr", ".cb7", ".cbt"]

  @doc """
  Scans the configured library path for comic files and returns a list of comic metadata.
  For performance with large libraries, this now supports limits and streaming.
  """
  def scan_library(opts \\ []) do
    library_path = get_library_path()

    if File.exists?(library_path) do
      scan_directory(library_path, opts)
    else
      Logger.warning("Comics library path does not exist: #{library_path}")
      []
    end
  end

  @doc """
  Quick scan that only returns basic file info without thumbnails.
  Much faster for large libraries.
  """
  def quick_scan_library(opts \\ []) do
    library_path = get_library_path()

    if File.exists?(library_path) do
      quick_scan_directory(library_path, opts)
    else
      Logger.warning("Comics library path does not exist: #{library_path}")
      []
    end
  end

  @doc """
  Gets a count of comics in the library without loading metadata.
  """
  def count_comics do
    library_path = get_library_path()

    if File.exists?(library_path) do
      Path.join(library_path, "**/*")
      |> Path.wildcard()
      |> Stream.filter(&is_comic_file?/1)
      |> Enum.count()
    else
      0
    end
  end

  @doc """
  Returns the configured library path.
  """
  def get_library_path do
    case Application.get_env(:basenji, :comics) do
      nil ->
        # Fallback to default path
        Path.join(File.cwd!(), "comics")

      config ->
        config[:library_path] || Path.join(File.cwd!(), "comics")
    end
  end

  @doc """
  Scans a directory for comic files with options for performance.
  Options:
    - limit: maximum number of comics to return
    - offset: number of comics to skip
    - thumbnails: whether to generate thumbnails (default: true)
    - sort_by: :title, :modified_at, :size (default: :title)
  """
  def scan_directory(path, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)
    thumbnails = Keyword.get(opts, :thumbnails, true)
    sort_by = Keyword.get(opts, :sort_by, :title)

    Path.join(path, "**/*")
    |> Path.wildcard()
    |> Stream.filter(&is_comic_file?/1)
    |> Stream.drop(offset)
    |> maybe_limit(limit)
    |> Stream.map(fn file_path ->
      if thumbnails do
        create_comic_metadata(file_path)
      else
        create_quick_metadata(file_path)
      end
    end)
    |> Stream.reject(&is_nil/1)
    |> Enum.to_list()
    |> sort_comics(sort_by)
  end

  @doc """
  Quick scan without thumbnails for performance.
  """
  def quick_scan_directory(path, opts \\ []) do
    scan_directory(path, Keyword.put(opts, :thumbnails, false))
  end

  @doc """
  Checks if a file is a supported comic book format.
  """
  def is_comic_file?(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    extension in @comic_extensions and File.regular?(file_path)
  end

  @doc """
  Creates metadata for a comic file including generating a thumbnail.
  """
  def create_comic_metadata(file_path) do
    try do
      # Generate thumbnail URL instead of base64 data
      thumbnail_url = generate_thumbnail_url(file_path)
      create_base_metadata(file_path, thumbnail_url)
    rescue
      error ->
        Logger.error("Error processing comic file #{file_path}: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Creates quick metadata without thumbnail for performance.
  """
  def create_quick_metadata(file_path) do
    try do
      create_base_metadata(file_path, nil)
    rescue
      error ->
        Logger.error("Error processing comic file #{file_path}: #{inspect(error)}")
        nil
    end
  end

  defp create_base_metadata(file_path, thumbnail) do
    stat = File.stat!(file_path)

    %{
      path: file_path,
      title: Path.basename(file_path, Path.extname(file_path)),
      filename: Path.basename(file_path),
      thumbnail: thumbnail,
      size: stat.size,
      modified_at: stat.mtime
    }
  end

  @doc """
  Generates a thumbnail from the first page of a comic, returning binary data.
  """
  def generate_thumbnail_binary(file_path) do
    case Reader.read(file_path) do
      {:ok, %{entries: entries}} ->
        # Find the first image file
        first_image_entry =
          entries
          |> Enum.filter(&is_image_file?/1)
          |> Enum.sort_by(& &1.file_name)
          |> List.first()

        case first_image_entry do
          nil ->
            {:error, "No image files found in comic"}

          entry ->
            try do
              # Get the image data from the stream
              image_data =
                entry.stream_fun.()
                |> Enum.to_list()
                |> IO.iodata_to_binary()

              # Detect content type
              content_type = detect_content_type(image_data)

              {:ok, {image_data, content_type}}
            rescue
              error ->
                {:error, "Failed to process image: #{inspect(error)}"}
            end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates a thumbnail from the first page of a comic.
  """
  def generate_thumbnail(file_path) do
    case generate_thumbnail_binary(file_path) do
      {:ok, {image_data, content_type}} ->
        base64_data = Base.encode64(image_data)
        data_url = "data:#{content_type};base64,#{base64_data}"
        {:ok, data_url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp is_image_file?(entry) do
    file_name = Map.get(entry, :file_name, "")
    extension = Path.extname(file_name) |> String.downcase()
    extension in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]
  end

  defp detect_content_type(<<0xFF, 0xD8, _rest::binary>>), do: "image/jpeg"
  defp detect_content_type(<<0x89, 0x50, 0x4E, 0x47, _rest::binary>>), do: "image/png"
  defp detect_content_type(<<0x47, 0x49, 0x46, _rest::binary>>), do: "image/gif"
  defp detect_content_type(<<"RIFF", _size::32-little, "WEBP", _rest::binary>>), do: "image/webp"
  defp detect_content_type(<<0x42, 0x4D, _rest::binary>>), do: "image/bmp"
  defp detect_content_type(_), do: "image/jpeg"

  @doc """
  Formats file size in human-readable format.
  """
  def format_file_size(size) when is_integer(size) do
    cond do
      size >= 1_073_741_824 -> "#{Float.round(size / 1_073_741_824, 1)} GB"
      size >= 1_048_576 -> "#{Float.round(size / 1_048_576, 1)} MB"
      size >= 1024 -> "#{Float.round(size / 1024, 1)} KB"
      true -> "#{size} B"
    end
  end

  defp maybe_limit(stream, nil), do: stream
  defp maybe_limit(stream, limit), do: Stream.take(stream, limit)

  defp sort_comics(comics, :title), do: Enum.sort_by(comics, & &1.title)

  defp sort_comics(comics, :modified_at),
    do: Enum.sort_by(comics, & &1.modified_at, {:desc, DateTime})

  defp sort_comics(comics, :size), do: Enum.sort_by(comics, & &1.size, :desc)
  defp sort_comics(comics, _), do: comics

  @doc """
  Generates a thumbnail URL for the first page of a comic.
  """
  def generate_thumbnail_url(file_path) do
    # Encode the file path to use in URL
    encoded_path = Base.url_encode64(file_path)
    "/thumbnail/#{encoded_path}"
  end
end
