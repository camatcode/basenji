defmodule Basenji.Worker.ComicWorker do
  @moduledoc false

  use Oban.Worker, queue: :comic, unique: [period: 30], max_attempts: 3

  alias __MODULE__, as: ComicWorker
  alias Basenji.Comic
  alias Basenji.Comics
  alias Basenji.Processor
  alias Basenji.Reader
  alias Basenji.Worker.ComicLowWorker

  require Logger

  def to_job(%{action: :insert, comic_id: comic_id}) do
    [
      to_job(%{action: :extract_metadata, comic_id: comic_id}),
      to_low_job(%{action: :snapshot, comic_id: comic_id}, schedule_in: 10),
      to_low_job(%{action: :optimize, comic_id: comic_id}, schedule_in: 10)
    ]
  end

  def to_job(%{action: :hash} = args), do: to_low_job(args, schedule_in: 10)

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

  defp extract_metadata(%Comic{} = comic, _args) do
    with {:ok, info} <- Reader.info(comic.resource_location),
         {:ok, comic} <- Comics.update_comic(comic, info) do
      Processor.process(comic, [:hash])
      :ok
    end
    |> case do
      {:error, :unreadable} -> Comics.delete_comic(comic.id)
      {:error, :no_reader_found} -> Comics.delete_comic(comic.id)
      resp -> resp
    end
  end

  defp extract_metadata(comic_id, args) do
    Comics.get_comic(comic_id)
    |> case do
      {:ok, %{page_count: -1} = comic} -> extract_metadata(comic, args)
      _ -> :ok
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
