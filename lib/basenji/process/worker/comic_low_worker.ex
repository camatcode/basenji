defmodule Basenji.Worker.ComicLowWorker do
  @moduledoc false

  use Oban.Worker, queue: :comic_low, unique: [period: 30], max_attempts: 3

  alias Basenji.Comics
  alias Basenji.ImageProcessor

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "comic_id" => comic_id} = args}) do
    case action do
      "snapshot" -> snapshot(comic_id, args)
      _ -> {:error, "Unknown action #{action}"}
    end
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      reraise e, __STACKTRACE__
  end

  defp snapshot(comic_id, _args) do
    with {:ok, comic} <- Comics.get_comic(comic_id),
         {:ok, bytes, _mime} = Comics.get_page(comic, 1),
         {:ok, preview_bytes} <- ImageProcessor.get_image_preview(bytes, 600, 600) do
      Comics.update_comic(comic, %{image_preview: preview_bytes})
    end
  end
end
