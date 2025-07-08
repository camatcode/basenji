defmodule Basenji.Worker.CollectionWorker do
  @moduledoc false

  use Oban.Worker, queue: :collection, unique: [period: 30], max_attempts: 3

  alias __MODULE__, as: CollectionWorker
  alias Basenji.Collection
  alias Basenji.Collections
  alias Basenji.Comics
  alias Basenji.Reader

  require Logger

  def to_job(%{action: :insert, collection_id: collection_id}) do
    [:explore_resource]
    |> Enum.map(&to_job(%{action: &1, collection_id: collection_id}))
  end

  def to_job(args), do: CollectionWorker.new(args)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "collection_id" => collection_id} = args}) do
    case action do
      "explore_resource" -> explore_resource(collection_id, args)
      _ -> {:error, "Unknown action #{action}"}
    end
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      reraise e, __STACKTRACE__
  end

  defp explore_resource(collection_id, _args) do
    with {:ok, collection} <- Collections.get_collection(collection_id) do
      explore_resource(collection)
    end
  end

  defp explore_resource(%Collection{resource_location: resource_location} = collection)
       when is_bitstring(resource_location) do
    path = Path.expand(resource_location)

    children = Path.wildcard("#{path}/*")

    files =
      Enum.filter(children, fn file ->
        File.regular?(file) && Reader.find_reader(file)
      end)

    dirs = Enum.filter(children, fn file -> File.dir?(file) end)

    if !Enum.empty?(files), do: insert_comics(collection, files)
    if !Enum.empty?(dirs), do: insert_collections(collection, dirs)
    :ok
  end

  defp insert_comics(parent_collection, files) when is_list(files) do
    {:ok, comics} =
      Enum.map(files, fn file ->
        %{resource_location: file}
      end)
      |> Comics.create_comics()

    Collections.add_to_collection(parent_collection, comics)
  end

  defp insert_collections(parent_collection, dirs) do
    Enum.map(dirs, fn dir ->
      if comics?(dir) do
        %{title: Path.basename(dir), parent_id: parent_collection.id, resource_location: dir}
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Collections.create_collections()
  end

  defp comics?(path) do
    children = Path.wildcard("#{path}/**/*")

    Enum.reduce_while(children, false, fn child, acc ->
      if comic?(child) do
        {:halt, true}
      else
        {:cont, acc}
      end
    end)
  end

  defp comic?(path) do
    if File.regular?(path) do
      Reader.find_reader(path)
      |> case do
        nil -> false
        _ -> true
      end
    else
      false
    end
  end
end
