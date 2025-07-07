defmodule Basenji.Processor do
  @moduledoc false

  alias Basenji.Collection
  alias Basenji.Comic
  alias Basenji.Worker.CollectionWorker
  alias Basenji.Worker.ComicWorker

  def process(%Comic{id: comic_id, resource_location: loc}, actions) when is_list(actions) do
    actions
    |> Enum.map(fn action -> ComicWorker.to_job(%{action: action, comic_id: comic_id, resource_location: loc}) end)
    |> List.flatten()
    |> Oban.insert_all()
  end

  def process(%Collection{id: collection_id}, actions) when is_list(actions) do
    actions
    |> Enum.map(fn action -> CollectionWorker.to_job(%{action: action, collection_id: collection_id}) end)
    |> List.flatten()
    |> Oban.insert_all()
  end
end
