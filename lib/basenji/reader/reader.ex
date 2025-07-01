defmodule Basenji.Reader do
  @moduledoc false

  alias Basenji.Reader.CB7Reader
  alias Basenji.Reader.CBRReader
  alias Basenji.Reader.CBTReader
  alias Basenji.Reader.CBZReader
  alias Basenji.Reader.Process.JPEGOptimizer
  alias Basenji.Reader.Process.PNGOptimizer
  alias Porcelain.Result

  @readers [
    CBZReader,
    CBRReader,
    CB7Reader,
    CBTReader
  ]

  @optimizers [
    JPEGOptimizer,
    PNGOptimizer
  ]

  def exec(cmd, args, opts \\ []) do
    Porcelain.exec(cmd, args, opts)
    |> case do
      %Result{out: output, status: 0} ->
        {:ok, output |> String.trim()}

      other ->
        {:error, other}
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

  def sort_file_names(e), do: Enum.sort_by(e, & &1.file_name)

  def reject_macos_preview(e), do: Enum.reject(e, &String.contains?(&1.file_name, "__MACOSX"))

  def read(file_path, opts \\ []) do
    opts = Keyword.merge([optimize: false], opts)

    reader =
      @readers
      |> Enum.reduce_while(
        nil,
        fn reader, _acc ->
          if matches_magic?(reader, file_path), do: {:halt, reader}, else: {:cont, nil}
        end
      )

    if reader do
      read_result = reader.read(file_path, opts)
      if opts[:optimize], do: optimize_entries(read_result), else: read_result
    else
      {:error, "No Reader found for: #{file_path}. Unknown file type"}
    end
  end

  def matches_magic?(reader, file_path) do
    reader.get_magic_numbers()
    |> Enum.reduce_while(
      nil,
      fn %{offset: offset, magic: magic}, _acc ->
        bytes =
          File.stream!(file_path, offset + Enum.count(magic), [])
          |> Enum.take(1)
          |> hd()
          |> :binary.bin_to_list()
          |> Enum.take(-1 * Enum.count(magic))

        if bytes == magic, do: {:halt, true}, else: {:cont, nil}
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
end
