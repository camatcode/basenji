defmodule Basenji.Reader do
  @moduledoc false

  alias Porcelain.Result

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
    readers = [
      Basenji.Reader.CBZReader,
      Basenji.Reader.CBRReader,
      Basenji.Reader.CB7Reader,
      Basenji.Reader.CBTReader
    ]

    reader =
      readers
      |> Enum.reduce_while(
        nil,
        fn reader, _acc ->
          if matches_magic?(reader, file_path), do: {:halt, reader}, else: {:cont, nil}
        end
      )

    if reader do
      reader.read(file_path, opts)
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
          File.stream!(file_path, [], offset + Enum.count(magic))
          |> Enum.take(1)
          |> hd()
          |> :binary.bin_to_list()
          |> Enum.take(-1 * Enum.count(magic))

        if bytes == magic, do: {:halt, true}, else: {:cont, nil}
      end
    )
  end
end
