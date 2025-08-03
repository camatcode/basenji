defmodule Basenji.Reader.CB7Reader do
  @moduledoc false

  @behaviour Basenji.Reader

  use Basenji.TelemetryHelpers

  alias Basenji.Reader

  @impl Reader
  def format, do: :cb7

  @impl Reader
  def file_extensions, do: ["cb7"]

  @impl Reader
  def magic_numbers, do: [%{offset: 0, magic: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]}]

  @impl Reader
  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, output} <- Reader.exec("7z", ["l", "-ba", cbz_file_path]) do
      output
      |> String.split("\n")
      |> Enum.map(&String.slice(&1, 53..-1//1))
      |> Enum.map(&%{file_name: &1})
      |> Reader.sort_and_reject()
      |> then(&{:ok, %{entries: &1}})
    end
  end

  @impl Reader
  def get_entry_stream!(cbz_file_path, entry),
    do: Reader.create_resource("7z", ["x", "-so", cbz_file_path, entry[:file_name]])

  @impl Reader
  def close(_), do: :ok
end
