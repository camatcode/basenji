defmodule Basenji.Processor do
  @moduledoc false

  alias Basenji.Collection
  alias Basenji.Comic
  alias Basenji.Worker.CollectionWorker
  alias Basenji.Worker.ComicWorker

  def process(thing, actions, opts \\ [])

  def process(list, actions, opts) when is_list(list) do
    opts = Keyword.put(opts, :insert, false)

    list
    |> Enum.map(fn thing -> process(thing, actions, opts) end)
    |> List.flatten()
    |> Oban.insert_all()
  end

  def process(%Comic{id: _} = comic, actions, opts) when is_list(actions) do
    opts = Keyword.merge([insert: true], opts)

    jobs =
      actions
      |> Enum.map(fn action -> ComicWorker.to_job(%{action: action, comic: comic}) end)
      |> Enum.filter(fn thing -> thing != nil end)
      |> List.flatten()

    if opts[:insert], do: Oban.insert_all(jobs), else: jobs
  end

  def process(%Collection{id: _} = collection, actions, opts) when is_list(actions) do
    opts = Keyword.merge([insert: true], opts)

    jobs =
      actions
      |> Enum.map(fn action -> CollectionWorker.to_job(%{action: action, collection: collection}) end)
      |> Enum.filter(fn thing -> thing != nil end)
      |> List.flatten()

    if opts[:insert], do: Oban.insert_all(jobs), else: jobs
  end
end
