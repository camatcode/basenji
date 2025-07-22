defmodule Basenji.ReaderTest do
  use ExUnit.Case

  alias Basenji.Reader

  doctest Basenji.Reader

  test "info" do
    examples = Basenji.Application.get_comics_directory()

    files = Path.wildcard("#{examples}/**/*.cb*") ++ Path.wildcard("#{examples}/**/*.pdf")
    refute Enum.empty?(files)

    files
    |> Enum.each(fn file ->
      {:ok, info} = Reader.info(file, include_hash: true)
      assert info.format
      assert info.title
      assert info.resource_location
      assert info.page_count
      assert info.hash
    end)
  end

  test "stream pages" do
    examples = Basenji.Application.get_comics_directory()

    files = Path.wildcard("#{examples}/**/*.cb*") ++ Path.wildcard("#{examples}/**/*.pdf")
    refute Enum.empty?(files)

    files
    |> Enum.each(fn file ->
      {:ok, stream} = Reader.stream_pages(file)

      stream
      |> Enum.each(fn page ->
        page_bytes = page |> Enum.to_list()
        refute Enum.empty?(page_bytes)
      end)
    end)
  end

  test "read" do
    tmp_dir = TestHelper.get_tmp_dir() |> Path.join("reader_test")

    examples = Basenji.Application.get_comics_directory()

    files = Path.wildcard("#{examples}/**/*.cb*") ++ Path.wildcard("#{examples}/**/*.pdf")
    refute Enum.empty?(files)

    files
    |> Enum.each(fn file ->
      assert {:ok, entries} = Reader.read(file)
      refute Enum.empty?(entries)

      assert {:ok, %{entries: optimized_entries}} = Reader.read(file, optimize: true, close: false)
      [random_entry] = Enum.shuffle(optimized_entries) |> Enum.take(1)

      path = Path.join(tmp_dir, random_entry.file_name)
      :ok = File.mkdir_p!(Path.dirname(path))
      file = File.stream!(path)

      random_entry.stream_fun.()
      |> Enum.into(file)

      File.close(file)

      %{size: size} = File.stat!(path)

      assert size != 0
      :ok = File.rm!(path)
    end)
  end
end
