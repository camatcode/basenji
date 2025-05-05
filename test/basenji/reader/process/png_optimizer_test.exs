defmodule Basenji.Reader.Process.PNGOptimizerTest do
  use ExUnit.Case
  doctest Basenji.Reader.Process.PNGOptimizer

  alias Basenji.Reader.Process.PNGOptimizer

  test "optimize_png" do
    png_dir =
      File.cwd!()
      |> Path.join("test/support/data/basenji/formats/png")

    png_files = Path.wildcard("#{png_dir}/**/*.png")
    refute Enum.empty?(png_files)

    png_files
    |> Enum.each(fn png_path ->
      orig_bytes = File.read!(png_path)
      orig_size = byte_size(orig_bytes)

      {:ok, optimized_bytes} = PNGOptimizer.optimize(orig_bytes)

      assert byte_size(optimized_bytes) != 0
      assert byte_size(optimized_bytes) <= orig_size
    end)

    not_png_dir =
      File.cwd!()
      |> Path.join("test/support/data/basenji/formats/jpeg")

    not_png_files = Path.wildcard("#{not_png_dir}/**/*.jp*")
    refute Enum.empty?(not_png_files)

    not_png_files
    |> Enum.each(fn not_png_path ->
      orig_bytes = File.read!(not_png_path)
      orig_size = byte_size(orig_bytes)

      {:ok, passed_through} = PNGOptimizer.optimize(orig_bytes)

      assert byte_size(passed_through) == orig_size
    end)
  end
end
