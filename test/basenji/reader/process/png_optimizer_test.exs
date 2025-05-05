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

      {:ok, optimized_bytes} = PNGOptimizer.optimize_png(orig_bytes)

      assert byte_size(optimized_bytes) != 0
      assert byte_size(optimized_bytes) <= orig_size
    end)
  end
end
