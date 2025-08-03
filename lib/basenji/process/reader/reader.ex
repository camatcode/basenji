defmodule Basenji.Reader do
  @moduledoc false

  use Basenji.TelemetryHelpers

  alias Basenji.CmdExecutor
  alias Basenji.Optimizer.JPEGOptimizer
  alias Basenji.Optimizer.PNGOptimizer
  alias Basenji.Reader.CB7Reader
  alias Basenji.Reader.CBRReader
  alias Basenji.Reader.CBTReader
  alias Basenji.Reader.CBZReader
  alias Basenji.Reader.PDFReader

  @readers [
    CBZReader,
    CBRReader,
    CB7Reader,
    CBTReader,
    PDFReader
  ]

  @optimizers [
    JPEGOptimizer,
    PNGOptimizer
  ]

  @image_extensions [
    "jpeg",
    "jpg",
    "jpe",
    "jif",
    "jfi",
    "jfif",
    "heif",
    "heic",
    "png",
    "gif",
    "svg",
    "eps",
    "webp",
    "tiff",
    "tif"
  ]

  @callback format() :: atom()
  @callback file_extensions() :: list()
  @callback magic_numbers :: [map()]
  @callback get_entries(file_path :: String.t(), opts :: list()) :: {:ok, map()} | {:error, any()}
  @callback get_entry_stream!(location :: String.t(), file_name :: String.t()) :: Enumerable.t()
  @callback close(any()) :: :ok | :error

  def read(file_path, opts \\ []) do
    opts = Keyword.merge([optimize: true], opts)

    reader = find_reader(file_path)

    if reader do
      read_result = read_from_location(reader, file_path)
      if opts[:optimize], do: optimize_entries(read_result), else: read_result
    else
      {:error, :no_reader_found}
    end
  end

  def stream_pages(file_path, opts \\ []) do
    opts = Keyword.merge([start_page: 1, optimize: true], opts)

    with {:ok, %{entries: entries}} <- read(file_path, opts) do
      stream =
        opts[:start_page]..Enum.count(entries)
        |> Stream.map(fn idx ->
          at = idx - 1
          Enum.at(entries, at).stream_fun.()
        end)

      {:ok, stream}
    end
  end

  def title_from_location(location) do
    location
    |> Path.basename()
    |> Path.rootname()
    |> ProperCase.snake_case()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize(&1))
  end

  def info(location, opts \\ []) do
    Cachex.fetch(
      :basenji_cache,
      info_cache_key(location, opts),
      fn _key ->
        any_result = get_info(location, opts)
        {:commit, any_result, [ttl: to_timeout(minute: 5)]}
      end
    )
    |> case do
      {:ignore, {:error, error}} ->
        {:error, error}

      {_, result} ->
        result

      response ->
        response
    end
  end

  def create_resource(make_func) do
    Stream.resource(
      make_func,
      fn
        :halt -> {:halt, nil}
        func -> {func, :halt}
      end,
      fn _ -> nil end
    )
  end

  def create_resource(cmd, args) do
    create_resource(fn ->
      with {:ok, output} <- CmdExecutor.exec(cmd, args) do
        [output |> :binary.bin_to_list()]
      end
    end)
  end

  def sort_and_reject(e) do
    e
    |> sort_file_names()
    |> reject_macos_preview()
    |> reject_directories()
    |> reject_non_image()
  end

  defp sort_file_names(e), do: Enum.sort_by(e, & &1.file_name)

  defp reject_macos_preview(e), do: Enum.reject(e, &String.contains?(&1.file_name, "__MACOSX"))

  defp reject_directories(e), do: Enum.reject(e, &(Path.extname(&1.file_name) == ""))

  defp reject_non_image(e) do
    Enum.filter(e, fn ent ->
      ext = Path.extname(ent.file_name) |> String.replace(".", "") |> String.downcase()
      ext in @image_extensions
    end)
  end

  defp matches_extension?(reader, filepath) do
    file_ext = Path.extname(filepath) |> String.downcase()

    reader.file_extensions()
    |> Enum.reduce_while(false, fn ext, acc ->
      if String.ends_with?(file_ext, ext), do: {:halt, true}, else: {:cont, acc}
    end)
  end

  defp matches_magic?(reader, file_path) do
    reader.magic_numbers()
    |> Enum.reduce_while(
      nil,
      fn %{offset: offset, magic: magic}, _acc ->
        try do
          bytes =
            File.stream!(file_path, offset + Enum.count(magic), [])
            |> Enum.take(1)
            |> hd()
            |> :binary.bin_to_list()
            |> Enum.take(-1 * Enum.count(magic))

          if bytes == magic, do: {:halt, true}, else: {:cont, nil}
        rescue
          _e ->
            {:cont, nil}
        end
      end
    )
  end

  defp optimize_entries({:ok, result}) do
    updated_entries =
      Map.get(result, :entries)
      |> Enum.map(fn entry ->
        stream_fun = fn ->
          create_resource(fn -> [optimize(entry.stream_fun.()) |> :binary.bin_to_list()] end)
        end

        Map.put(entry, :stream_fun, stream_fun)
      end)

    result = Map.put(result, :entries, updated_entries)

    {:ok, result}
  end

  defp optimize_entries(other), do: other

  defp optimize(bytes) do
    @optimizers
    |> Enum.reduce(bytes |> Enum.to_list(), fn reader, bytes ->
      reader.optimize!(bytes)
    end)
  end

  defp info_cache_key(location, opts), do: %{location: location, opts: opts}

  defp read_from_location(reader, location) do
    meter_duration [:basenji, :process], "read_#{reader.format()}" do
      with {:ok, %{entries: file_entries}} <- reader.get_entries(location) do
        file_entries =
          file_entries
          |> Enum.map(&Map.put(&1, :stream_fun, fn -> reader.get_entry_stream!(location, &1) end))

        {:ok, %{entries: file_entries}}
      end
    end
  end

  defp get_info(location, _opts) do
    reader = find_reader(location)

    info =
      if reader do
        title = title_from_location(location)

        {:ok, response} = read_from_location(reader, location)
        %{entries: entries} = response
        reader.close(response[:file])

        %{
          format: reader.format(),
          resource_location: location,
          title: title,
          page_count: Enum.count(entries)
        }
      else
        {:error, :unreadable}
      end

    info
    |> case do
      {:error, e} -> {:error, e}
      inf -> {:ok, inf}
    end
  end

  defp find_reader(file_path) do
    @readers
    |> Enum.reduce_while(
      nil,
      fn reader, _acc ->
        if matches_extension?(reader, file_path) && matches_magic?(reader, file_path),
          do: {:halt, reader},
          else: {:cont, nil}
      end
    )
  end
end
