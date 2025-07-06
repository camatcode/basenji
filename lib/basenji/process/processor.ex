defmodule Basenji.Processor do
  @moduledoc false

  alias Basenji.Comic
  alias Basenji.Worker.ComicWorker

  def process(%Comic{id: comic_id, resource_location: loc}, actions) when is_list(actions) do
    actions
    |> Enum.map(fn action -> ComicWorker.to_job(%{action: action, comic_id: comic_id, resource_location: loc}) end)
    |> List.flatten()
    |> Oban.insert_all()
  end
end
