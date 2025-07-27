defmodule Basenji.Reader.CBTReader do
  @moduledoc false
  use Basenji.TelemetryHelpers

  import Basenji.Reader

  def format, do: :cbt

  def close(_any), do: :ok

  def file_extensions, do: ["cbt"]

  def get_magic_numbers, do: [%{offset: 257, magic: ~c"ustar"}]

  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, file_names} <- :erl_tar.table(cbz_file_path, [:compressed]) do
      file_entries =
        file_names
        |> Enum.map(&%{file_name: "#{&1}"})
        |> sort_file_names()
        |> reject_macos_preview()
        |> reject_directories()
        |> reject_non_image()

      {:ok, %{entries: file_entries}}
    end
  end

  def get_entry_stream!(cbz_file_path, entry) do
    escaped_filename = entry[:file_name]

    file_name = ~c"#{escaped_filename}"

    create_resource(fn ->
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
end
