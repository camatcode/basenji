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
      {:ok, optimized} = ComicOptimizer.optimize(file_path, TestHelper.get_tmp_dir(), TestHelper.get_tmp_dir())

      assert ComicOptimizer.basenji_comment?(optimized)

      on_exit(fn ->
        File.rm_rf(TestHelper.get_tmp_dir())
      end)

      {:ok, optimized_info} = Reader.info(optimized)

      assert original_info.page_count == optimized_info.page_count
    end)
  end
end
