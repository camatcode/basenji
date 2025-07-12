defmodule Basenji.Reader.Process.ComicOptimizer do
  @moduledoc false

  alias Basenji.Reader

  def optimize(comic_file_path, result_directory) do
    if String.ends_with?(comic_file_path, "optimized.cbz") || basenji_comment?(comic_file_path) do
      {:ok, comic_file_path}
    else
      :ok = File.mkdir_p!(result_directory)

      comic_name =
        Path.basename(comic_file_path)
        |> Path.rootname()
        |> ProperCase.snake_case()

      images_dir = Path.join(result_directory, "#{comic_name}_images")
      :ok = File.mkdir_p!(images_dir)

      with {:ok, %{page_count: page_count}} <- Reader.info(comic_file_path),
           {:ok, %{entries: entries}} <- Reader.read(comic_file_path),
           {:ok, stream} <- Reader.stream_pages(comic_file_path, optimize: true) do
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

        response = zip(result_directory, "#{comic_name}_images", optimized_name)
        File.rm_rf!(images_dir)
        response
      end
    end
  end

  def basenji_comment?(comic_file_path) do
    {:ok, %{format: format}} = Reader.info(comic_file_path)

    if format == :cbz do
      Reader.exec("zipinfo", ["-z", comic_file_path])
      |> case do
        {:ok, output} ->
          String.contains?(output, "Optimized by Basenji")

        other ->
          IO.inspect(other)
          false
      end
    else
      false
    end
  end

  defp zip(parent_dir, images_dir_name, zip_file_name) do
    flags = [
      # Recursive
      "-r",
      # Maximum compression level
      "-9",
      # Quiet
      "-q"
    ]

    System.cmd("zip", flags ++ [zip_file_name, images_dir_name], cd: parent_dir)
    |> case do
      {_, 0} ->
        comment = "Optimized by Basenji v#{Application.spec(:basenji, :vsn)} on #{DateTime.utc_now()}"
        System.cmd("sh", ["-c", "echo '#{comment}' | zip -z #{zip_file_name}"], cd: parent_dir)
        {:ok, Path.join(parent_dir, zip_file_name)}

      {error_output, exit_code} ->
        {:error, {exit_code, error_output}}
    end
  end
end
