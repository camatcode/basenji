defmodule Basenji.Collections do
  @moduledoc false

  import Basenji.ContextUtils
  import Ecto.Query

  alias Basenji.Collection
  alias Basenji.CollectionComic
  alias Basenji.Comic
  alias Basenji.Comics
  alias Basenji.Repo

  def create_collection(attrs, opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    %Collection{collection_comics: []}
    |> Collection.changeset(attrs)
    |> Repo.insert(opts[:repo_opts])
  end

  def from_resource(path, attrs, opts \\ []) do
    path = Path.expand(path)

    comics =
      Path.wildcard("#{path}/**/*.cb*")
      |> Enum.map(fn file ->
        Comics.from_resource(file, %{})
        |> case do
          {:ok, created} ->
            created

          _ ->
            nil
        end
      end)
      |> Enum.filter(&Function.identity/1)

    with {:ok, collection} <- create_collection(attrs, opts) do
      Enum.each(comics, fn c -> add_to_collection(collection, c) end)
      opts = Keyword.put(opts, :preload, collection_comics: [:comic], parent: [])
      get_collection(collection.id, opts)
    end
  end

  def list_collections(opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    Collection
    |> reduce_collection_opts(opts)
    |> Repo.all(opts[:repo_opts])
  end

  def get_collection(id, opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    from(c in Collection, where: c.id == ^id)
    |> reduce_collection_opts(opts)
    |> Repo.one(opts[:repo_opts])
    |> case do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  def update_collection(collection_ref, attrs, opts \\ [])

  def update_collection(%Collection{} = collection, attrs, opts) do
    with {:ok, collection} <-
           collection
           |> Collection.changeset(attrs)
           |> Repo.update() do
      if opts[:preload] do
        get_collection(collection.id, opts)
      else
        {:ok, collection}
      end
    end
  end

  def update_collection(id, attrs, opts) when is_bitstring(id) do
    with {:ok, collection} <- get_collection(id, opts) do
      update_collection(collection, attrs, opts)
    end
  end

  def add_to_collection(collection_ref, comic_ref, attrs \\ %{}, opts \\ [])

  def add_to_collection(%Collection{id: collection_id}, %Comic{id: comic_id}, attrs, opts) do
    add_to_collection(collection_id, comic_id, attrs, opts)
  end

  def add_to_collection(collection_id, comic_id, attrs, opts) do
    opts = Keyword.merge([repo_opts: []], opts)

    %CollectionComic{collection_id: collection_id, comic_id: comic_id}
    |> Basenji.CollectionComic.changeset(attrs)
    |> Repo.insert(opts[:repo_opts])
  end

  def delete_collection(collection_ref)

  def delete_collection(nil), do: nil

  def delete_collection(%Collection{id: collection_id}) do
    delete_collection(collection_id)
  end

  def delete_collection(collection_id) do
    Repo.delete(%Collection{id: collection_id})
  end

  def remove_from_collection(%CollectionComic{id: _coll_comic_id} = coll_comic) do
    Repo.delete(coll_comic)
  end

  def remove_from_collection(collection_ref, comic_ref)

  def remove_from_collection(%Collection{id: collection_id}, %Comic{id: comic_id}) do
    remove_from_collection(collection_id, comic_id)
  end

  def remove_from_collection(collection_id, comic_id) do
    from(c in CollectionComic,
      where: c.collection_id == ^collection_id and c.comic_id == ^comic_id
    )
    |> Repo.one()
    |> case do
      nil -> {:ok, nil}
      col_comic -> remove_from_collection(col_comic)
    end
  end

  defp reduce_collection_opts(query, opts) do
    {query, opts} = reduce_opts(query, opts)

    Enum.reduce(opts, query, fn
      {_any, ""}, query ->
        query

      {_any, nil}, query ->
        query

      {:search, search}, query ->
        term = "%#{search}%"

        where(query, [c], ilike(c.title, ^term))
        |> or_where([c], ilike(c.description, ^term))

      {:title, search}, query ->
        term = "%#{search}%"
        where(query, [c], ilike(c.title, ^term))

      {:description, search}, query ->
        term = "%#{search}%"
        where(query, [c], ilike(c.description, ^term))

      {:parent_id, p_id}, query ->
        where(query, [c], c.parent_id == ^p_id)

      _, query ->
        query
    end)
  end
end
