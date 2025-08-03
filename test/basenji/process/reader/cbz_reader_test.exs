defmodule Basenji.Reader.CBZReaderTest do
  use ExUnit.Case

  alias Basenji.Reader
  alias Basenji.Reader.CBZReader

  doctest CBZReader

  test "get_entries/1" do
    assert {:error, _} = CBZReader.get_entries("does-not-exist")

    # Test with our known test file
    test_file = "test/support/data/basenji/formats/cbz/bobby_make_believe_sample.cbz"

    {:ok, %{entries: entries}} = CBZReader.get_entries(test_file)
    refute Enum.empty?(entries)

    entries
    |> Enum.each(fn entry ->
      assert entry.file_name
    end)
  end

  test "read" do
    tmp_dir = TestHelper.get_tmp_dir() |> Path.join("cbz_read_test")

    test_file = "test/support/data/basenji/formats/cbz/bobby_make_believe_sample.cbz"

    {:ok, %{entries: entries}} = Reader.read(test_file)
    refute Enum.empty?(entries)

    [random_entry] = Enum.shuffle(entries) |> Enum.take(1)

    path = Path.join(tmp_dir, random_entry.file_name)
    :ok = File.mkdir_p!(Path.dirname(path))

    # Test that we can extract the file
    File.open!(path, [:write, :binary], fn file ->
      random_entry.stream_fun.() |> Enum.each(&IO.binwrite(file, &1))
    end)

    # Verify file was created and has content
    %{size: size} = File.stat!(path)
    assert size > 0

    :ok = File.rm!(path)
  end

  test "parallel processing" do
    test_file = "test/support/data/basenji/formats/cbz/bobby_make_believe_sample.cbz"

    {:ok, %{entries: entries}} = Reader.read(test_file)

    # Test that multiple tasks can access the same file concurrently
    tasks =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {entry, index} ->
        Task.async(fn ->
          data = entry.stream_fun.() |> Enum.to_list() |> IO.iodata_to_binary()
          {index, byte_size(data)}
        end)
      end)

    results = Enum.map(tasks, &Task.await(&1, 10_000))

    # Verify all tasks completed successfully
    assert length(results) == length(entries)

    # Verify all files had content
    results
    |> Enum.each(fn {_index, size} ->
      assert size > 0
    end)
  end
end
