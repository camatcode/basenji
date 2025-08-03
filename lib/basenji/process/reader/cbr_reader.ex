defmodule Basenji.Reader.CBRReader do
  @moduledoc false
  @behaviour Basenji.Reader

  use Basenji.TelemetryHelpers

  alias Basenji.CmdExecutor
  alias Basenji.Reader

  @impl Reader
  def format, do: :cbr

  @impl Reader
  def file_extensions, do: ["cbr"]

  @impl Reader
  def magic_numbers, do: [%{offset: 0, magic: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]}]

  @impl Reader
  def get_entries(cbr_file_path, _opts \\ []) do
    with {:ok, output} <- CmdExecutor.exec("unrar", ["lb", cbr_file_path]) do
      String.split(output, "\n")
      |> Enum.map(&%{file_name: &1})
      |> Reader.sort_and_reject()
      |> then(&{:ok, %{entries: &1}})
    end
  end

  @impl Reader
  def get_entry_stream!(cbr_file_path, entry),
    do: Reader.create_resource("unrar", ["p", cbr_file_path, entry[:file_name]])

  @impl Reader
  def close(_), do: :ok
end
