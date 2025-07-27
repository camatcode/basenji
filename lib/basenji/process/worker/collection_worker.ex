defmodule Basenji.Worker.CollectionWorker do
  @moduledoc false

  use Oban.Worker, queue: :collection, unique: [period: 60, keys: [:collection_id, :action]], max_attempts: 3

  alias __MODULE__, as: CollectionWorker
  alias Basenji.Collection
  alias Basenji.Collections
  alias Basenji.Comics

  require Logger

  def to_job(%{action: :insert, collection_id: collection_id}) do
    [:explore_resource]
    |> Enum.map(&to_job(%{action: &1, collection_id: collection_id}))
  end

  def to_job(args), do: CollectionWorker.new(args)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action, "collection_id" => collection_id} = args}) do
    start = System.monotonic_time()
    result = do_work(action, collection_id, args)
    :telemetry.execute([:basenji, :oban, :worker], %{duration: System.monotonic_time() - start}, %{action: action})
    result
  end

  defp do_work(action, collection_id, args) do
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
    case Collections.get_collection(collection_id) do
      {:ok, %{resource_location: resource_location} = collection} when not is_nil(resource_location) ->
        explore_resource(collection)

      _ ->
        :ok
    end
  end

  defp walk(path) do
    File.ls!(path)
    |> Enum.reduce({[], []}, fn file_or_dir, {dirs, files} ->
      full_path = Path.join(path, file_or_dir)

      if File.dir?(full_path) do
        {child_dirs, child_files} = walk(full_path)
        dirs = [full_path] ++ child_dirs ++ dirs
        files = files ++ child_files
        {dirs |> List.flatten() |> Enum.uniq(), files |> List.flatten() |> Enum.uniq()}
      else
        {dirs, [full_path | files] |> Enum.uniq()}
      end
    end)
  end

  defp explore_resource(%Collection{resource_location: resource_location} = collection)
       when is_bitstring(resource_location) do
    path = Path.expand(resource_location)

    {dirs, files} = walk(path)

    if Enum.empty?(files) && Enum.empty?(dirs) do
      Collections.delete_collection(collection)
    else
      if !Enum.empty?(files), do: insert_comics(collection, files)
      if Enum.empty?(dirs), do: :ok, else: insert_collections(collection, dirs)
    end
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
      File.ls!(dir)
      |> case do
        [] -> nil
        _ -> %{title: Path.basename(dir), parent_id: parent_collection.id, resource_location: dir}
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Collections.create_collections()

    :ok
  end
end
