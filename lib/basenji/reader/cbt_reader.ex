defmodule Basenji.Reader.CBTReader do
  @moduledoc false
  @behaviour Basenji.Reader

  use Basenji.TelemetryHelpers

  alias Basenji.Reader

  @impl Reader
  def format, do: :cbt

  @impl Reader
  def file_extensions, do: ["cbt"]

  @impl Reader
  def magic_numbers, do: [%{offset: 257, magic: ~c"ustar"}]

  @impl Reader
  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, file_names} <- :erl_tar.table(cbz_file_path, [:compressed]) do
      file_entries =
        file_names
        |> Enum.map(&%{file_name: "#{&1}"})
        |> Reader.sort_file_names()
        |> Reader.reject_macos_preview()
        |> Reader.reject_directories()
        |> Reader.reject_non_image()

      {:ok, %{entries: file_entries}}
    end
  end

  @impl Reader
  def read(cbz_file_path, _opts \\ []) do
    meter_duration [:basenji, :process], "read_cbt" do
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
    escaped_filename = entry[:file_name]

    file_name = ~c"#{escaped_filename}"

    Reader.create_resource(fn ->
      with {:ok, [{^file_name, data}]} <-
             :erl_tar.extract(cbz_file_path, [
               {:files, [file_name]},
               :compressed,
               :memory
             ]) do
        [data |> :binary.bin_to_list()]
      end
    end)
  end
end
