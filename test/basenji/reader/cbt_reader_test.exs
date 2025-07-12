defmodule Basenji.Reader.CBTReaderTest do
  use ExUnit.Case

  alias Basenji.Reader.CBTReader

  doctest CBTReader

  test "get_entries" do
    cbt_dir = Basenji.Application.get_comics_directory()

    cbt_files = Path.wildcard("#{cbt_dir}/**/*.cbt")
    refute Enum.empty?(cbt_files)

    cbt_files
    |> Enum.each(fn cbt_path ->
      {:ok, %{entries: entries}} = CBTReader.get_entries(cbt_path)
      refute Enum.empty?(entries)

      entries
      |> Enum.each(fn entry ->
        assert entry.file_name
      end)
    end)
  end

  test "read" do
    tmp_dir = TestHelper.get_tmp_dir() |> Path.join("cbr_read_test")

    cbt_dir = Basenji.Application.get_comics_directory()

    cbt_files = Path.wildcard("#{cbt_dir}/**/*.cbt")
    refute Enum.empty?(cbt_files)

    cbt_files
    #
    |> Enum.each(fn cbt_file_path ->
      {:ok, %{entries: entries}} = CBTReader.read(cbt_file_path)
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
