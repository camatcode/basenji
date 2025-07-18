defmodule Basenji.Worker.ComicMedWorker do
  @moduledoc false

  use Oban.Worker, queue: :comic_med, unique: [period: 30], max_attempts: 3

  alias Basenji.Comics
  alias Basenji.ImageProcessor

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "comic_id" => comic_id} = args}) do
    Comics.get_comic(comic_id)
    |> case do
      {:ok, comic} ->
        case action do
          "snapshot" -> snapshot(comic, args)
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

  defp snapshot(%{image_preview_id: id}, _args) when is_bitstring(id), do: :ok

  defp snapshot(comic, _args) do
    with {:ok, bytes, _mime} <- Comics.get_page(comic, 1),
         {:ok, preview_bytes} <- ImageProcessor.get_image_preview(bytes, 600, 600) do
      Comics.associate_image_preview(comic, preview_bytes, width: 600, height: 600)
    end
  end
end
