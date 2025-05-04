defmodule Basenji.ReaderTest do
  use ExUnit.Case
  doctest Basenji.Reader

  alias Basenji.Reader

  test "read" do
    examples =
      File.cwd!()
      |> Path.join("test/support/data/basenji/formats/")

    files = Path.wildcard("#{examples}/**/*.*")
    refute Enum.empty?(files)

    files
    |> Enum.each(fn file ->
      assert {:ok, _entries} = Reader.read(file)
    end)
  end
end
