defmodule Basenji.Reader.CBRReaderTest do
  use ExUnit.Case

  alias Basenji.Reader.CBRReader

  doctest CBRReader

  test "get_entries" do
    cbr_dir = Basenji.Application.get_comics_directory()

    cbr_files = Path.wildcard("#{cbr_dir}/**/*.cbr")
    refute Enum.empty?(cbr_files)

    cbr_files
    |> Enum.each(fn cbr_path ->
      {:ok, %{entries: entries}} = CBRReader.get_entries(cbr_path)
      refute Enum.empty?(entries)

      entries
      |> Enum.each(fn entry ->
        assert entry.file_name
      end)
    end)
  end

  test "read" do
    tmp_dir = TestHelper.get_tmp_dir() |> Path.join("cbr_read_test")

    cbr_dir = Basenji.Application.get_comics_directory()

    cbr_files = Path.wildcard("#{cbr_dir}/**/*.cbr")
    refute Enum.empty?(cbr_files)

    cbr_files
    |> Enum.each(fn cbr_file_path ->
      {:ok, %{entries: entries}} = CBRReader.read(cbr_file_path)
      refute Enum.empty?(entries)

      [random_entry] = Enum.shuffle(entries) |> Enum.take(1)

      path = Path.join(tmp_dir, random_entry.file_name)
      :ok = File.mkdir_p!(Path.dirname(path))
      file = File.stream!(path)
      random_entry.stream_fun.() |> Enum.into(file)
      File.close(file)

      %{size: size} = File.stat!(path)

      assert size != 0
      :ok = File.rm!(path)
    end)
  end
end
