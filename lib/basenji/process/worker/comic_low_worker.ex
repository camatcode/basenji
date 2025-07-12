defmodule Basenji.Worker.ComicLowWorker do
  @moduledoc false

  use Oban.Worker, queue: :comic_low, unique: [period: 30], max_attempts: 3

  alias Basenji.Comics
  alias Basenji.ImageProcessor
  alias Basenji.Reader.Process.ComicOptimizer

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "comic_id" => comic_id} = args}) do
    Comics.get_comic(comic_id)
    |> case do
      {:ok, comic} ->
        case action do
          "snapshot" -> snapshot(comic, args)
          "optimize" -> optimize(comic, args)
          _ -> {:error, "Unknown action #{action}"}
        end

      _ ->
        :ok
    end
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      reraise e, __STACKTRACE__
  end

  defp snapshot(%{image_preview: preview}, _args) when is_binary(preview), do: :ok

  defp snapshot(comic, _args) do
    with {:ok, bytes, _mime} <- Comics.get_page(comic, 1),
         {:ok, preview_bytes} <- ImageProcessor.get_image_preview(bytes, 600, 600) do
      Comics.update_comic(comic, %{image_preview: preview_bytes})
    end
  end

  defp optimize(%{optimized_id: nil, original_id: nil, resource_location: resource_location} = comic, _args) do
    Logger.info(
      "Attempting to optimize comic: #{inspect(%{id: comic.id, optimized_id: comic.optimized_id, original_id: comic.original_id, resource_location: comic.resource_location})}"
    )

    parent_dir = Path.join(Path.dirname(resource_location), "optimized")

    with {:ok, optimized_resource_location} <- ComicOptimizer.optimize(resource_location, parent_dir) do
      if optimized_resource_location == resource_location do
        :ok
      else
        Comics.create_optimized_comic(comic, %{resource_location: optimized_resource_location})
      end
    end
  end

  defp optimize(_comic, _args), do: :ok
end
