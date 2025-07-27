defmodule Basenji.Reader.CBZReader do
  @moduledoc false
  use Basenji.TelemetryHelpers

  import Basenji.Reader

  def format, do: :cbz

  def file_extensions, do: ["cbz"]

  def close(_any), do: :ok

  def get_magic_numbers, do: [%{offset: 0, magic: [0x50, 0x4B, 0x03, 0x04]}]

  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, output} <- exec("zipinfo", ["-1", cbz_file_path]) do
      file_names = output |> String.split("\n")

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

      with {:ok, output} <- exec("unzip", ["-p", cbz_file_path, escaped_filename]) do
        [output |> :binary.bin_to_list()]
      end
    end)
  end

  def read(cbz_file_path, _opts \\ []) do
    telemetry_wrap [:basenji, :process], %{action: "read_cbz"} do
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
end
