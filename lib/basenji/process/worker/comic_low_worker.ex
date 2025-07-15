defmodule Basenji.Worker.ComicLowWorker do
  @moduledoc false

  use Oban.Worker, queue: :comic_low, unique: [period: 3000], max_attempts: 3

  alias Basenji.ComicClassifier
  alias Basenji.Comics
  alias Basenji.Reader.Process.ComicOptimizer

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "comic_id" => comic_id} = args}) do
    Comics.get_comic(comic_id)
    |> case do
      {:ok, comic} ->
        case action do
          "optimize" -> optimize(comic, args)
          "determine_style" -> determine_style(comic, args)
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

  defp optimize(%{optimized_id: nil, original_id: nil, resource_location: resource_location} = comic, _args) do
    Logger.info(
      "Attempting to optimize comic: #{inspect(%{id: comic.id, optimized_id: comic.optimized_id, original_id: comic.original_id, resource_location: comic.resource_location})}"
    )

    parent_dir = Path.join(Path.dirname(resource_location), "optimized")
    tmp_dir = Path.join(System.tmp_dir!(), "basenji")

    with {:ok, optimized_resource_location} <- ComicOptimizer.optimize(resource_location, tmp_dir, parent_dir) do
      if optimized_resource_location == resource_location do
        :ok
      else
        Comics.create_optimized_comic(comic, %{resource_location: optimized_resource_location})
      end
    end
  end

  defp optimize(_comic, _args), do: :ok

  defp determine_style(%{style: nil} = comic, _args) do
    {:ok, style} = ComicClassifier.classify(comic)
    Comics.update_comic(comic, %{style: style})
  end

  defp determine_style(_, _), do: :ok
end
