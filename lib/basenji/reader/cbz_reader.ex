defmodule Basenji.Reader.CBZReader do
  @moduledoc false
  import Basenji.Reader

  def format, do: :cbz

  def file_extensions, do: ["cbz"]

  def close(_any), do: :ok

  def get_magic_numbers, do: [%{offset: 0, magic: [0x50, 0x4B, 0x03, 0x04]}]

  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, output} <- exec("unzip", ["-l", cbz_file_path]) do
      file_names = parse_unzip_listing(output)

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
      with {:ok, output} <- exec("unzip", ["-p", cbz_file_path, entry[:file_name]]) do
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

  # Parse unzip -l output to extract filenames
  defp parse_unzip_listing(output) do
    output
    |> String.split("\n")
    # Skip header
    |> Enum.drop_while(&(not String.contains?(&1, "----")))
    # Skip the ---- line itself
    |> Enum.drop(1)
    # Take until footer ----
    |> Enum.take_while(&(not String.contains?(&1, "----")))
    |> Enum.map(&extract_filename_from_line/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_filename_from_line(line) do
    line
    |> String.trim()
    |> String.split()
    |> case do
      [_size, _date, _time | filename_parts] -> Enum.join(filename_parts, " ")
      _ -> ""
    end
  end
end
