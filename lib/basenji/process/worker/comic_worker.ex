defmodule Basenji.Worker.ComicWorker do
  @moduledoc false

  use Oban.Worker, queue: :comic, unique: [period: 30], max_attempts: 3

  alias __MODULE__, as: ComicWorker
  alias Basenji.Comics
  alias Basenji.ImageProcessor
  alias Basenji.Reader

  require Logger

  def to_job(%{action: :insert, comic_id: comic_id}) do
    [:extract_metadata, :snapshot]
    |> Enum.map(&to_job(%{action: &1, comic_id: comic_id}))
  end

  def to_job(args) do
    ComicWorker.new(args)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "comic_id" => comic_id} = args}) do
    case action do
      "extract_metadata" -> extract_metadata(comic_id, args)
      "snapshot" -> snapshot(comic_id, args)
      "delete" -> delete(args)
      _ -> {:error, "Unknown action #{action}"}
    end
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      reraise e, __STACKTRACE__
  end

  defp extract_metadata(comic_id, _args) do
    with {:ok, comic} <- Comics.get_comic(comic_id),
         {:ok, info} <- Reader.info(comic.resource_location) do
      Comics.update_comic(comic, info)
    end
  end

  defp snapshot(comic_id, _args) do
    with {:ok, comic} <- Comics.get_comic(comic_id),
         {:ok, bytes, _mime} = Comics.get_page(comic, 1),
         {:ok, preview_bytes} <- ImageProcessor.get_image_preview(bytes, 600, 600) do
      Comics.update_comic(comic, %{image_preview: preview_bytes})
    end
  end

  defp delete(%{"resource_location" => loc}) do
    if Application.get_env(:basenji, :allow_delete_resources) == true do
      Comics.list_comics(resource_location: loc)
      |> case do
        [] -> File.rm(loc)
        _ -> :ok
      end
    else
      :ok
    end
  end
end
