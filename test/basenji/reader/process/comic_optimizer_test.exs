defmodule Basenji.Reader.Process.ComicOptimizerTest do
  use ExUnit.Case

  alias Basenji.Reader
  alias Basenji.Reader.Process.ComicOptimizer

  @moduletag :capture_log

  doctest ComicOptimizer

  test "scratch" do
    file_path =
      "/home/cam/Documents/comics_backup/done/Wynd Book 01 - The Flight of the Prince (2021) (DR & Quinch-Empire) (AI-HD juvecube).cbz"

    ComicOptimizer.optimize(file_path, "/home/cam/tmp/wynd/") |> IO.inspect()
    #Basenji.Reader.optimize_directory("/home/cam/tmp/wynd")
  end

  test "optimize" do
    comics_dir = Basenji.Application.get_comics_directory()

    comics = Path.wildcard("#{comics_dir}/**/*.cb*") ++ Path.wildcard("#{comics_dir}/**/*.pdf")

    Enum.each(comics, fn file_path ->
      {:ok, original_info} = Reader.info(file_path)
      {:ok, optimized} = ComicOptimizer.optimize(file_path, TestHelper.get_tmp_dir())

      assert ComicOptimizer.basenji_comment?(optimized)

      on_exit(fn ->
        File.rm_rf(TestHelper.get_tmp_dir())
      end)

      {:ok, optimized_info} = Reader.info(optimized)

      assert original_info.page_count == optimized_info.page_count
    end)
  end
end
