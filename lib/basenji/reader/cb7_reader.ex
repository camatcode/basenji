defmodule Basenji.Reader.CB7Reader do
  @moduledoc false

  import Basenji.Reader

  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, output} <- exec("7z", ["l", "-ba", cbz_file_path]) do
      file_names =
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(&String.slice(&1, 53..-1//1))

      file_entries =
        file_names
        |> Enum.map(&%{file_name: &1})
        |> sort_file_names()
        |> reject_macos_preview()

      {:ok, %{entries: file_entries}}
    end
  end

  def get_entry_stream!(cbz_file_path, entry) do
    create_resource(fn ->
      with {:ok, output} <- exec("7z", ["x", "-so", cbz_file_path, entry[:file_name]]) do
        [output |> :binary.bin_to_list()]
      end
    end)
  end

  def read(cbz_file_path, _opts \\ []) do
    with {:ok, %{entries: file_entries}} <- get_entries(cbz_file_path) do
      file_entries =
        file_entries
        |> Enum.map(fn entry ->
          entry
          |> Map.put(:stream_fun, fn -> get_entry_stream!(cbz_file_path, entry) end)
        end)

      {:ok, %{entries: file_entries}}
    end
  end
end
