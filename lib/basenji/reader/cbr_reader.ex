defmodule Basenji.Reader.CBRReader do
  @moduledoc false
  @behaviour Basenji.Reader

  use Basenji.TelemetryHelpers

  alias Basenji.Reader

  @impl Reader
  def format, do: :cbr

  @impl Reader
  def file_extensions, do: ["cbr"]

  @impl Reader
  def magic_numbers, do: [%{offset: 0, magic: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]}]

  @impl Reader
  def get_entries(cbr_file_path, _opts \\ []) do
    with {:ok, output} <- Reader.exec("unrar", ["lb", cbr_file_path]) do
      file_names = String.split(output, "\n")

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
  def read(cbr_file_path, _opts \\ []) do
    meter_duration [:basenji, :process], "read_cbr" do
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

  @impl Reader
  def close(_), do: :ok

  defp get_entry_stream!(cbr_file_path, entry) do
    Reader.create_resource(fn ->
      escaped_filename = entry[:file_name]

      with {:ok, output} <- Reader.exec("unrar", ["p", cbr_file_path, escaped_filename]) do
        [output |> :binary.bin_to_list()]
      end
    end)
  end
end
