defmodule Basenji.Reader.CBZReader do
  @moduledoc false
  @behaviour Basenji.Reader

  use Basenji.TelemetryHelpers

  alias Basenji.CmdExecutor
  alias Basenji.Reader

  @impl Reader
  def format, do: :cbz

  @impl Reader
  def file_extensions, do: ["cbz"]

  @impl Reader
  def magic_numbers, do: [%{offset: 0, magic: [0x50, 0x4B, 0x03, 0x04]}]

  @impl Reader
  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, output} <- CmdExecutor.exec("zipinfo", ["-1", cbz_file_path]) do
      output
      |> String.split("\n")
      |> Enum.map(&%{file_name: &1})
      |> Reader.sort_and_reject()
      |> then(&{:ok, %{entries: &1}})
    end
  end

  @impl Reader
  def get_entry_stream!(cbz_file_path, entry),
    do: Reader.create_resource("unzip", ["-p", cbz_file_path, entry[:file_name]])

  @impl Reader
  def close(_), do: :ok
end
