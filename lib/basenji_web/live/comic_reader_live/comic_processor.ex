defmodule BasenjiWeb.ComicReaderLive.ComicProcessor do
  @moduledoc """
  Handles comic file processing logic for the ComicReaderLive.
  """

  require Logger

  @doc """
  Gets comic metadata without loading page data - fast for lazy loading.
  """
  def get_comic_metadata(file_path) do
    case Basenji.Reader.read(file_path) do
      {:ok, %{entries: entries}} ->
        # Filter for image files and sort them
        image_entries =
          entries
          |> Enum.filter(&is_image_file?/1)
          |> Enum.sort_by(& &1.file_name)

        # Create page metadata without loading actual image data
        pages =
          image_entries
          |> Enum.with_index()
          |> Enum.map(fn {entry, index} ->
            %{
              index: index,
              name: entry.file_name,
              # Will be loaded on demand
              data_url: nil,
              # Keep reference for lazy loading
              entry: entry
            }
          end)

        metadata = %{
          file_path: file_path,
          total_entries: length(entries),
          image_entries: length(image_entries),
          processed_pages: length(pages)
        }

        {:ok, {pages, metadata}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Loads a specific page by index - for lazy loading.
  """
  def load_page(page_info) do
    case stream_to_base64(page_info.entry) do
      {:ok, data_url} ->
        {:ok, %{page_info | data_url: data_url}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Loads comic pages from a file path - DEPRECATED: Use get_comic_metadata + load_page for lazy loading.
  """
  def load_comic_pages(file_path) do
    case Basenji.Reader.read(file_path) do
      {:ok, %{entries: entries}} ->
        # Filter for image files and sort them
        image_entries =
          entries
          |> Enum.filter(&is_image_file?/1)
          |> Enum.sort_by(& &1.file_name)

        # Convert entries to base64 data URLs for display
        pages =
          image_entries
          |> Enum.with_index()
          |> Enum.map(fn {entry, index} ->
            case stream_to_base64(entry) do
              {:ok, data_url} ->
                %{
                  index: index,
                  name: entry.file_name,
                  data_url: data_url
                }

              {:error, reason} ->
                Logger.warning("Failed to process page",
                  entry: entry.file_name,
                  error: inspect(reason)
                )

                nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        metadata = %{
          file_path: file_path,
          total_entries: length(entries),
          image_entries: length(image_entries),
          processed_pages: length(pages)
        }

        {:ok, {pages, metadata}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates if a file extension is supported for comic books.
  """
  def supported_comic_extension?(file_name) do
    extension = Path.extname(file_name) |> String.downcase()
    extension in [".cbz", ".cbr", ".cb7", ".cbt"]
  end

  @doc """
  Cleans up temporary comic files.
  """
  def cleanup_comic_files(file_path) do
    if File.exists?(file_path) do
      File.rm(file_path)
    end
  end

  # Private functions

  defp is_image_file?(entry) do
    file_name = Map.get(entry, :file_name, "")
    extension = Path.extname(file_name) |> String.downcase()
    extension in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]
  end

  defp stream_to_base64(entry) do
    try do
      # Get the image data from the stream
      image_data =
        entry.stream_fun.()
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      # Detect content type
      content_type = detect_content_type(image_data)

      # Convert to base64 data URL
      base64_data = Base.encode64(image_data)
      data_url = "data:#{content_type};base64,#{base64_data}"

      {:ok, data_url}
    rescue
      error ->
        {:error, error}
    end
  end

  defp detect_content_type(<<0xFF, 0xD8, _rest::binary>>), do: "image/jpeg"
  defp detect_content_type(<<0x89, 0x50, 0x4E, 0x47, _rest::binary>>), do: "image/png"
  defp detect_content_type(<<0x47, 0x49, 0x46, _rest::binary>>), do: "image/gif"
  defp detect_content_type(<<"RIFF", _size::32-little, "WEBP", _rest::binary>>), do: "image/webp"
  defp detect_content_type(<<0x42, 0x4D, _rest::binary>>), do: "image/bmp"
  defp detect_content_type(_), do: "image/jpeg"
end
