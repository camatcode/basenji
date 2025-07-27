defmodule Basenji.Reader.CBRReader do
  @moduledoc false
  use Basenji.TelemetryHelpers

  import Basenji.Reader

  def format, do: :cbr
  def file_extensions, do: ["cbr"]
  def close(_any), do: :ok

  def get_magic_numbers, do: [%{offset: 0, magic: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]}]

  def get_entries(cbr_file_path, _opts \\ []) do
    with {:ok, output} <- exec("unrar", ["lb", cbr_file_path]) do
      file_names = String.split(output, "\n")

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

  def get_entry_stream!(cbr_file_path, entry) do
    create_resource(fn ->
      escaped_filename = entry[:file_name]

      with {:ok, output} <- exec("unrar", ["p", cbr_file_path, escaped_filename]) do
        [output |> :binary.bin_to_list()]
      end
    end)
  end

  def read(cbr_file_path, _opts \\ []) do
    telemetry_wrap [:basenji, :process], %{action: "read_cbr"} do
      with {:ok, %{entries: file_entries}} <- get_entries(cbr_file_path) do
        file_entries =
          file_entries
          |> Enum.map(fn entry ->
            entry
            |> Map.put(:stream_fun, fn -> get_entry_stream!(cbr_file_path, entry) end)
          end)

        {:ok, %{entries: file_entries}}
      end
    end
  end
end
