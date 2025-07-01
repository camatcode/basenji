defmodule Basenji.Reader.CBZReaderTest do
  use ExUnit.Case

  alias Basenji.Reader.CBZReader

  doctest CBZReader

  test "get_entries/1" do
    assert {:error, _} = CBZReader.get_entries("does-not-exist")

    cbz_dir = Basenji.Application.get_comics_directory()

    cbz_files = Path.wildcard("#{cbz_dir}/**/*.cbz")

    refute Enum.empty?(cbz_files)

    cbz_files
    |> Enum.each(fn cbz_file_path ->
      {:ok, %{entries: entries}} = CBZReader.get_entries(cbz_file_path, close: true)
      refute Enum.empty?(entries)

      entries
      |> Enum.each(fn entry ->
        assert entry.file_name
        assert entry.last_modified_datetime
        assert entry.compressed_size
        assert entry.uncompressed_size
      end)
    end)
  end

  test "read" do
    tmp_dir = System.tmp_dir!() |> Path.join("cbz_read_test")

    cbz_dir = Basenji.Application.get_comics_directory()

    cbz_files = Path.wildcard("#{cbz_dir}/**/*.cbz")
    refute Enum.empty?(cbz_files)

    cbz_files
    |> Enum.each(fn cbz_file_path ->
      {:ok, %{entries: entries, file: unzip}} = CBZReader.read(cbz_file_path)
      refute Enum.empty?(entries)

      [random_entry] = Enum.shuffle(entries) |> Enum.take(1)

      path = Path.join(tmp_dir, random_entry.file_name)
      :ok = File.mkdir_p!(Path.dirname(path))
      file = File.stream!(path)
      random_entry.stream_fun.() |> Enum.into(file)
      File.close(file)
      :ok = CBZReader.close(unzip)

      %{size: size} = File.stat!(path)
      assert size == random_entry.uncompressed_size

      :ok = File.rm!(path)
    end)
  end
end
