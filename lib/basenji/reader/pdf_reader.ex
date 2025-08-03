defmodule Basenji.Reader.PDFReader do
  @moduledoc false
  @behaviour Basenji.Reader

  use Basenji.TelemetryHelpers

  alias Basenji.Reader

  @impl Reader
  def format, do: :pdf

  @impl Reader
  def file_extensions, do: ["pdf"]

  @impl Reader
  def magic_numbers, do: [%{offset: 0, magic: [0x25, 0x50, 0x44, 0x46, 0x2D]}]

  @impl Reader
  def get_entries(pdf_file_path, _opts \\ []) do
    with {:ok, %{pages: pages}} <- get_metadata(pdf_file_path) do
      padding = String.length("#{pages}")

      file_entries =
        1..pages
        |> Enum.map(fn idx ->
          %{file_name: "#{String.pad_leading("#{idx}", padding, "0")}.jpg"}
        end)

      {:ok, %{entries: file_entries}}
    end
  end

  @impl Reader
  def read(pdf_file_path, _opts \\ []) do
    meter_duration [:basenji, :process], "read_pdf" do
      with {:ok, %{entries: file_entries}} <- get_entries(pdf_file_path) do
        file_entries =
          file_entries
          |> Enum.map(fn entry ->
            entry
            |> Map.put(:stream_fun, fn -> get_entry_stream!(pdf_file_path, entry) end)
          end)

        {:ok, %{entries: file_entries}}
      end
    end
  end

  @impl Reader
  def close(_), do: :ok

  defp get_entry_stream!(pdf_file_path, entry) do
    file_name = entry[:file_name]
    {page_num, _rest} = Integer.parse(file_name)

    Reader.create_resource(fn ->
      with {:ok, output} <- Reader.exec("pdftoppm", ["-f", "#{page_num}", "-singlefile", "-jpeg", "-q", pdf_file_path]) do
        [output |> :binary.bin_to_list()]
      end
    end)
  end

  defp get_metadata(pdf_file_path) do
    with {:ok, output} <- Reader.exec("pdfinfo", ["-isodates", pdf_file_path]) do
      metadata =
        String.split(output, "\n")
        |> Map.new(fn line ->
          String.split(line, ":", parts: 2)
          |> case do
            [k, v] -> to_metadata(k, v)
            [v] -> to_metadata("unknown_#{System.monotonic_time()}", v)
          end
        end)

      {:ok, metadata}
    end
  end

  defp to_metadata(k, v) do
    k = k |> String.trim() |> ProperCase.snake_case() |> String.to_atom()
    v = convert_value(k, v |> String.trim())
    {k, v}
  end

  defp convert_value(:creation_date, v), do: DateTimeParser.parse!(v)
  defp convert_value(:mod_date, v), do: DateTimeParser.parse!(v)
  defp convert_value(:pages, v), do: String.to_integer(v)

  defp convert_value(:filesize, v) do
    {first, _rest} = Integer.parse(v)
    first
  end

  defp convert_value(:pagesize, v) do
    String.split(v, " ")
    |> Enum.reduce([], fn part, acc ->
      Integer.parse(part)
      |> case do
        {coord, _rest} -> [coord | acc]
        _ -> acc
      end
    end)
    |> case do
      [x, y] -> {x, y}
      _ -> v
    end
  end

  defp convert_value(_k, "yes"), do: true
  defp convert_value(_k, "no"), do: false
  defp convert_value(_k, "none"), do: nil
  defp convert_value(_k, v), do: v
end
