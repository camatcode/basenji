defmodule Basenji.Worker.ComicLowWorker do
  @moduledoc false

  use Oban.Worker, queue: :comic_low, unique: [period: 3000], max_attempts: 3

  alias Basenji.Collections
  alias Basenji.Comics
  alias Basenji.ImageProcessor
  alias Basenji.Reader.Process.ComicOptimizer
  alias Basenji.UserPresenceTracker

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "comic_id" => comic_id} = args}) do
    if UserPresenceTracker.anyone_browsing?() do
      Logger.debug("Someone is browsing, snoozing low comic #{comic_id} for 5 minutes")
      {:snooze, 300}
    else
      do_work(action, comic_id, args)
    end
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      reraise e, __STACKTRACE__
  end

  def do_work(action, comic_id, args) do
    Comics.get_comic(comic_id)
    |> case do
      {:ok, comic} ->
        case action do
          "optimize" -> optimize(comic, args)
          "snapshot" -> snapshot(comic, args)
          "hash" -> hash(comic, args)
          _ -> {:error, "Unknown action #{action}"}
        end

      _ ->
        :ok
    end
  end

  defp optimize(%{optimized_id: nil, original_id: nil, resource_location: resource_location} = comic, _args) do
    parent_dir = Path.join(Path.dirname(resource_location), "optimized")
    tmp_dir = Path.join(System.tmp_dir!(), "basenji")

    with {:ok, optimized_resource_location} <- ComicOptimizer.optimize(resource_location, tmp_dir, parent_dir) do
      if optimized_resource_location == resource_location do
        Comics.update_comic(comic, %{pre_optimized?: true})
      else
        Comics.create_optimized_comic(comic, %{resource_location: optimized_resource_location})
      end
    end
  end

  defp optimize(_comic, _args), do: :ok
  defp snapshot(%{image_preview_id: id}, _args) when is_bitstring(id), do: :ok

  defp snapshot(comic, _args) do
    with {:ok, bytes, _mime} <- Comics.get_page(comic, 1),
         {:ok, preview_bytes} <- ImageProcessor.get_image_preview(bytes, 400, 600) do
      Comics.associate_image_preview(comic, preview_bytes, width: 400, height: 600)
    end
  end

  defp hash(%{hash: hash}, _args) when is_bitstring(hash), do: :ok

  defp hash(comic, _args) do
    with {:ok, hash} <- Comics.get_hash(comic) do
      dupes = Comics.list_comics(hash: hash)

      if Enum.empty?(dupes) do
        Comics.update_comic(comic, %{hash: hash})
      else
        deduplicate(comic, dupes)
      end
    end
  end

  defp deduplicate(comic, dupes) do
    with {:ok, comic} <- Comics.get_comic(comic.id, preload: [:member_collections]) do
      [earliest | rest] = dupes |> Enum.sort_by(& &1.inserted_at)

      comic.member_collections
      |> Enum.each(fn member_collection ->
        Collections.add_to_collection(member_collection.id, earliest.id)
      end)

      if !Enum.empty?(rest) do
        [head | dupes] = rest
        deduplicate(head, [earliest | dupes])
      end

      Comics.delete_comic(comic)
    end
  end
end
