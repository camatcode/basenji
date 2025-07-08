defmodule Basenji.Worker.ComicWorker do
  @moduledoc false

  use Oban.Worker, queue: :comic, unique: [period: 30], max_attempts: 3

  alias __MODULE__, as: ComicWorker
  alias Basenji.Comics
  alias Basenji.Reader
  alias Basenji.Worker.ComicLowWorker

  require Logger

  def to_job(%{action: :insert, comic_id: comic_id}) do
    [
      to_job(%{action: :extract_metadata, comic_id: comic_id}),
      to_low_job(%{action: :snapshot, comic_id: comic_id}, schedule_in: 10)
    ]
  end

  def to_low_job(args, opts \\ []) do
    ComicLowWorker.new(args, opts)
  end

  def to_job(args, opts \\ []) do
    ComicWorker.new(args, opts)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "comic_id" => comic_id} = args}) do
    case action do
      "extract_metadata" -> extract_metadata(comic_id, args)
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
         {:ok, attrs} <- Reader.info(comic.resource_location) do
      Comics.update_comic(comic, attrs)
    end
    |> case do
      {:error, :unreadable} -> Comics.delete_comic(comic_id)
      {:error, :no_reader_found} -> Comics.delete_comic(comic_id)
      resp -> resp
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
