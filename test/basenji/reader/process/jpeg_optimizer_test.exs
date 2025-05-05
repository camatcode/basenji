defmodule Basenji.Reader.Process.JPEGOptimizerTest do
  use ExUnit.Case
  doctest Basenji.Reader.Process.JPEGOptimizer

  alias Basenji.Reader.Process.JPEGOptimizer

  test "optimize_jpeg" do
    jpeg_dir =
      File.cwd!()
      |> Path.join("test/support/data/basenji/formats/jpeg")

    jpeg_files = Path.wildcard("#{jpeg_dir}/**/*.jp*")
    refute Enum.empty?(jpeg_files)

    jpeg_files
    |> Enum.each(fn jpeg_path ->
      orig_bytes = File.read!(jpeg_path)
      orig_size = byte_size(orig_bytes)

      {:ok, optimized_bytes} = JPEGOptimizer.optimize_jpeg(orig_bytes)

      assert byte_size(optimized_bytes) != 0
      assert byte_size(optimized_bytes) <= orig_size
    end)
  end
end
