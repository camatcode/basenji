defmodule Basenji.Reader.CB7Reader do
  @moduledoc false

  import Basenji.Reader

  def format, do: :cb7

  def file_extensions, do: ["cb7"]

  def close(_any), do: :ok

  def get_magic_numbers, do: [%{offset: 0, magic: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]}]

  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, output} <- exec("7z", ["l", "-ba", cbz_file_path]) do
      file_names =
        output
        |> String.split("\n")
        |> Enum.map(&String.slice(&1, 53..-1//1))

      file_entries =
        file_names
        |> Enum.map(&%{file_name: &1})
        |> sort_file_names()
        |> reject_macos_preview()
        |> reject_directories()
        |> reject_non_image()

      {:ok, %{entries: file_entries}}
    end
  end

  def get_entry_stream!(cbz_file_path, entry) do
    create_resource(fn ->
      escaped_filename = entry[:file_name]

      with {:ok, output} <- exec("7z", ["x", "-so", cbz_file_path, escaped_filename]) do
        [output |> :binary.bin_to_list()]
      end
    end)
  end

  def read(cbz_file_path, _opts \\ []) do
    with {:ok, %{entries: file_entries}} <- get_entries(cbz_file_path) do
      file_entries =
        file_entries
        |> Enum.map(&Map.put(&1, :stream_fun, fn -> get_entry_stream!(cbz_file_path, &1) end))

      {:ok, %{entries: file_entries}}
    end
  end
end
