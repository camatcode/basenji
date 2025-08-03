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
      file_names
      |> Enum.map(&%{file_name: "#{&1}"})
      |> Reader.sort_and_reject()
      |> then(&{:ok, %{entries: &1}})
    end
  end

  @impl Reader
  def get_entry_stream!(cbz_file_path, entry) do
    file_name = ~c"#{entry[:file_name]}"

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

  @impl Reader
  def close(_), do: :ok
end
