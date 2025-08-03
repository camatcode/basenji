defmodule Basenji.Reader.CBZReader do
  @moduledoc false
  @behaviour Basenji.Reader

  use Basenji.TelemetryHelpers

  alias Basenji.Reader

  @impl Reader
  def format, do: :cbz

  @impl Reader
  def file_extensions, do: ["cbz"]

  @impl Reader
  def magic_numbers, do: [%{offset: 0, magic: [0x50, 0x4B, 0x03, 0x04]}]

  @impl Reader
  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, output} <- Reader.exec("zipinfo", ["-1", cbz_file_path]) do
      file_names = output |> String.split("\n")

      file_entries =
        file_names
        |> Enum.map(&%{file_name: &1})
        |> Reader.sort_file_names()
        |> Reader.reject_macos_preview()
        |> Reader.reject_directories()
        |> Reader.reject_non_image()

      {:ok, %{entries: file_entries}}
    end
  end

  @impl Reader
  def read(cbz_file_path, _opts \\ []) do
    meter_duration [:basenji, :process], "read_cbz" do
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

  @impl Reader
  def close(_), do: :ok

  defp get_entry_stream!(cbz_file_path, entry) do
    Reader.create_resource(fn ->
      escaped_filename = entry[:file_name]

      with {:ok, output} <- Reader.exec("unzip", ["-p", cbz_file_path, escaped_filename]) do
        [output |> :binary.bin_to_list()]
      end
    end)
  end
end
