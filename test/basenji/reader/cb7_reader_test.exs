defmodule Basenji.Reader.CB7ReaderTest do
  use ExUnit.Case

  alias Basenji.Reader.CB7Reader

  doctest CB7Reader

  test "get_entries" do
    cb7_dir =
      Basenji.Application.get_comics_directory()
      |> Path.join("/cb7")

    cb7_files = Path.wildcard("#{cb7_dir}/**/*.cb7")
    refute Enum.empty?(cb7_files)

    cb7_files
    |> Enum.each(fn cb7_path ->
      {:ok, %{entries: entries}} = CB7Reader.get_entries(cb7_path)
      refute Enum.empty?(entries)

      entries
      |> Enum.each(fn entry ->
        assert entry.file_name
      end)
    end)
  end

  test "read" do
    tmp_dir = System.tmp_dir!() |> Path.join("cb7_read_test")

    cb7_dir = Basenji.Application.get_comics_directory()

    cb7_files = Path.wildcard("#{cb7_dir}/**/*.cb7")
    refute Enum.empty?(cb7_files)

    cb7_files
    |> Enum.each(fn cb7_file_path ->
      {:ok, %{entries: entries}} = CB7Reader.read(cb7_file_path)
      refute Enum.empty?(entries)

      [random_entry] = Enum.shuffle(entries) |> Enum.take(1)

      path = Path.join(tmp_dir, random_entry.file_name)
      :ok = File.mkdir_p!(Path.dirname(path))
      file = File.stream!(path)
      random_entry.stream_fun.() |> Enum.into(file)
      File.close(file)

      %{size: size} = File.stat!(path)

      assert size != 0
      # :ok = File.rm!(path)
    end)
  end
end
