defmodule Basenji.Optimizer.JPEGOptimizerTest do
  use ExUnit.Case

  alias Basenji.Optimizer.JPEGOptimizer

  doctest JPEGOptimizer

  test "optimize_jpeg" do
    jpeg_dir = Basenji.Application.get_comics_directory()

    jpeg_files = Path.wildcard("#{jpeg_dir}/**/*.jp*")
    refute Enum.empty?(jpeg_files)

    jpeg_files
    |> Enum.each(fn jpeg_path ->
      orig_bytes = File.read!(jpeg_path)
      orig_size = byte_size(orig_bytes)

      {:ok, optimized_bytes} = JPEGOptimizer.optimize(orig_bytes)

      assert byte_size(optimized_bytes) != 0
      assert byte_size(optimized_bytes) <= orig_size
    end)

    not_jpeg_dir = Basenji.Application.get_comics_directory()

    not_jpeg_files = Path.wildcard("#{not_jpeg_dir}/**/*.png")
    refute Enum.empty?(not_jpeg_files)

    not_jpeg_files
    |> Enum.each(fn not_jpeg_path ->
      orig_bytes = File.read!(not_jpeg_path)
      orig_size = byte_size(orig_bytes)

      {:ok, passed_through} = JPEGOptimizer.optimize(orig_bytes)

      assert byte_size(passed_through) == orig_size
    end)
  end
end
