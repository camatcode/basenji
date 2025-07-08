defmodule Basenji.Reader.PDFReaderTest do
  use ExUnit.Case

  alias Basenji.Reader.PDFReader

  @moduletag :capture_log

  doctest PDFReader

  test "get_entries/1" do
    assert {:error, _} = PDFReader.get_entries("does-not-exist")

    dir = Basenji.Application.get_comics_directory()

    files = Path.wildcard("#{dir}/**/*.pdf")

    refute Enum.empty?(files)

    files
    |> Enum.each(fn pdf_file_path ->
      {:ok, %{entries: entries}} = PDFReader.get_entries(pdf_file_path)
      refute Enum.empty?(entries)

      entries
      |> Enum.each(fn entry ->
        assert entry.file_name
      end)
    end)
  end

  test "read" do
    tmp_dir = System.tmp_dir!() |> Path.join("pdf_read_test")

    dir = Basenji.Application.get_comics_directory()

    files = Path.wildcard("#{dir}/**/*.pdf")
    refute Enum.empty?(files)

    files
    |> Enum.each(fn pdf_file_path ->
      {:ok, %{entries: entries}} = PDFReader.read(pdf_file_path)
      refute Enum.empty?(entries)

      [random_entry] = Enum.shuffle(entries) |> Enum.take(1)

      path = Path.join(tmp_dir, random_entry.file_name)
      :ok = File.mkdir_p!(Path.dirname(path))
      file = File.stream!(path)
      random_entry.stream_fun.() |> Enum.into(file)
      File.close(file)
      :ok = PDFReader.close(pdf_file_path)

      %{size: size} = File.stat!(path)
      assert size > 0

      :ok = File.rm!(path)
    end)
  end
end
