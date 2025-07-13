defmodule Basenji.Reader.Process.ComicOptimizer do
  @moduledoc false

  alias Basenji.FilenameSanitizer
  alias Basenji.Reader

  require Logger

  def optimize(comic_file_path, tmp_dir, result_directory) do
    if String.ends_with?(comic_file_path, "optimized.cbz") || basenji_comment?(comic_file_path) do
      {:ok, comic_file_path}
    else
      comic_name =
        Path.basename(comic_file_path)
        |> Path.rootname()
        |> FilenameSanitizer.sanitize()

      with {:ok, %{page_count: page_count}} <- Reader.info(comic_file_path),
           {:ok, %{entries: entries}} <- Reader.read(comic_file_path, optimize: true) do
        :ok = File.mkdir_p!(tmp_dir)
        :ok = File.mkdir_p!(result_directory)

        image_dir_name = "images#{System.monotonic_time()}"
        images_dir = Path.join(tmp_dir, image_dir_name)
        :ok = File.mkdir_p!(images_dir)

        padding = String.length("#{page_count}")

        1..page_count
        |> Task.async_stream(
          &extract_page(&1, entries, padding, images_dir),
          max_concurrency: 8,
          timeout: max(300_000, page_count * 2_000)
        )
        |> Stream.run()

        optimized_name = "#{comic_name}_optimized.cbz"

        zip(tmp_dir, image_dir_name, optimized_name, result_directory)
      end
    end
  end

  defp extract_page(page_idx, entries, padding, images_dir) do
    %{file_name: file_name, stream_fun: stream_func} = Enum.at(entries, page_idx - 1)
    ext = Path.extname(file_name)
    clean_name = "#{String.pad_leading("#{page_idx + 1}", padding, "0")}#{ext}"
    file_path = Path.join(images_dir, clean_name)

    File.open!(file_path, [:write, :binary], fn file ->
      stream_func.() |> Enum.each(&IO.binwrite(file, &1))
    end)
  end

  def basenji_comment?(comic_file_path) do
    {:ok, %{format: format}} = Reader.info(comic_file_path)

    if format == :cbz do
      Reader.exec("zipinfo", ["-z", comic_file_path])
      |> case do
        {:ok, output} ->
          String.contains?(output, "Optimized by Basenji")

        _ ->
          false
      end
    else
      false
    end
  end

  defp zip(parent_dir, images_dir_name, zip_file_name, result_directory) do
    flags = [
      # Recursive
      "-r",
      # Maximum compression level
      "-9",
      # Quiet
      "-q"
    ]

    response =
      System.cmd("zip", flags ++ [zip_file_name, images_dir_name], cd: parent_dir)
      |> case do
        {_, 0} ->
          comment = "Optimized by Basenji v#{Application.spec(:basenji, :vsn)} on #{DateTime.utc_now()}"
          System.cmd("sh", ["-c", "echo '#{comment}' | zip -z #{zip_file_name}"], cd: parent_dir)
          zip_file = Path.join(parent_dir, zip_file_name)
          final_place = Path.join(result_directory, zip_file_name)
          :ok = File.cp!(zip_file, final_place)
          :ok = File.rm!(zip_file)
          {:ok, final_place}

        {error_output, exit_code} ->
          {:error, {exit_code, error_output}}
      end

    File.rm_rf!(Path.join(parent_dir, images_dir_name))
    response
  end
end
