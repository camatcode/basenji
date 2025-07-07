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

    children
    |> Enum.each(fn child ->
      dir? = File.dir?(child)
      regular? = File.regular?(child)
      handle_child(collection, child, dir?, regular?)
    end)
  end

  defp handle_child(parent_collection, child, true, false) do
    if comics?(child) do
      title = Path.basename(child)
      attrs = %{title: title, parent_id: parent_collection.id, resource_location: child}
      Collections.create_collection(attrs)
    end
  end

  defp handle_child(parent_collection, child, false, true) do
    with {:ok, _info} <- Reader.info(child),
         {:ok, comic} <- Comics.from_resource(child, %{}) do
      Collections.add_to_collection(parent_collection, comic)
    end
  end

  defp handle_child(_, _, _, _), do: :ok

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

  def comic?(path) do
    if File.regular?(path) do
      Reader.info(path)
      |> case do
        {:ok, _info} -> true
        _ -> false
      end
    else
      false
    end
  end
end
