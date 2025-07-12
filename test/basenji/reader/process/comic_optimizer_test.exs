defmodule Basenji.Reader.Process.ComicOptimizerTest do
  use ExUnit.Case

  alias Basenji.Reader
  alias Basenji.Reader.Process.ComicOptimizer

  @moduletag :capture_log

  doctest ComicOptimizer

  test "optimize" do
    comics_dir = Basenji.Application.get_comics_directory()

    comics = Path.wildcard("#{comics_dir}/**/*.cb*") ++ Path.wildcard("#{comics_dir}/**/*.pdf")

    Enum.each(comics, fn file_path ->
      {:ok, original_info} = Reader.info(file_path)
      {:ok, %{size: original_size}} = File.lstat(file_path)
      {:ok, optimized} = ComicOptimizer.optimize(file_path)
      on_exit(fn ->

        File.rm_rf(optimized)
      
      end)
      {:ok, optimized_info} = Reader.info(optimized)
      {:ok, %{size: optimized_size}} = File.lstat(optimized)

      assert original_info.page_count == optimized_info.page_count

      if original_info.format != :pdf do
        assert optimized_size <= original_size
      end
    end)
  end
end
