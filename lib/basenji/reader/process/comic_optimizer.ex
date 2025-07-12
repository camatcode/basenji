defmodule Basenji.Reader.Process.ComicOptimizer do
  @moduledoc false

  import Basenji.Reader

  def optimize(comic_file_path) do
    tmp_dir =
      System.tmp_dir!()
      |> Path.join("basenji")
      |> Path.join("basenji_optimize_#{System.monotonic_time()}")

    :ok = File.mkdir_p!(tmp_dir)

    comic_name =
      Path.basename(comic_file_path)
      |> Path.rootname()
      |> ProperCase.snake_case()

    images_dir = Path.join(tmp_dir, "#{comic_name}_images")
    :ok = File.mkdir_p!(images_dir)

    with {:ok, %{page_count: page_count}} <- info(comic_file_path),
         {:ok, %{entries: entries}} <- read(comic_file_path),
         {:ok, stream} <- stream_pages(comic_file_path, optimize: true) do
      padding = String.length("#{page_count}") - 1

      stream
      |> Stream.with_index()
      |> Enum.each(fn {page, page_idx} ->
        page_bytes = page |> Enum.to_list()
        ext = Enum.at(entries, page_idx) |> Map.get(:file_name) |> Path.extname()

        file_name = "#{String.pad_leading("#{page_idx + 1}", padding, "0")}#{ext}"
        :ok = File.write!(Path.join(images_dir, file_name), page_bytes)
      end)

      optimized_name = "#{comic_name}_optimized.cbz"

      response = zip(tmp_dir, "#{comic_name}_images", optimized_name)
      File.rm_rf!(images_dir)
      response
    end
  end

  defp zip(parent_dir, images_dir_name, zip_file_name) do
    flags = [
      # Recursive
      "-r",
      # Maximum compression level
      "-9",
      # Quiet
      "-q",
      # Use deflate compression method
      "-Z",
      "bzip2"
    ]

    System.cmd("zip", flags ++ [zip_file_name, images_dir_name], cd: parent_dir)
    |> case do
      {_, 0} ->
        {:ok, Path.join(parent_dir, zip_file_name)}

      {error_output, exit_code} ->
        {:error, {exit_code, error_output}}
    end
  end
end
