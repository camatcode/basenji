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
      tmp_file = Path.join(TestHelper.get_tmp_dir(), "#{System.monotonic_time()}" <> Path.extname(file_path))
      :ok = File.mkdir_p!(TestHelper.get_tmp_dir())
      :ok = File.cp!(file_path, tmp_file)
      {:ok, original_info} = Reader.info(tmp_file)
      other = Path.join(TestHelper.get_tmp_dir(), "bar")
      {:ok, optimized} = ComicOptimizer.optimize(tmp_file, TestHelper.get_tmp_dir(), other)
      assert ComicOptimizer.basenji_comment?(optimized)

      on_exit(fn ->
        File.rm_rf(TestHelper.get_tmp_dir())
        File.rm(tmp_file)
      end)

      {:ok, optimized_info} = Reader.info(optimized)

      assert original_info.page_count == optimized_info.page_count
    end)
  end
end
