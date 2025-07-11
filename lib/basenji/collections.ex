defmodule Basenji.Collections do
  @moduledoc false

  import Basenji.ContextUtils
  import Ecto.Query

  alias Basenji.Collection
  alias Basenji.CollectionComic
  alias Basenji.Comic
  alias Basenji.Processor
  alias Basenji.Repo

  def create_collection(attrs, opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    insert_collection(attrs, opts)
    |> handle_insert_side_effects()
  end

  def create_collections(attrs_list, _opts \\ []) when is_list(attrs_list) do
    Enum.reduce(attrs_list, Ecto.Multi.new(), fn attrs, multi ->
      Ecto.Multi.insert(
        multi,
        System.monotonic_time(),
        Collection.changeset(%Collection{}, attrs),
        on_conflict: :nothing
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, transactions} ->
        collections =
          transactions
          |> Map.values()
          |> Enum.map(fn collection -> list_collections(title: collection.title) |> hd() end)

        handle_insert_side_effects({:ok, collections})

      e ->
        e
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
    has_comics_operations = Map.has_key?(attrs, :comics_to_add) || Map.has_key?(attrs, :comics_to_remove)

    if has_comics_operations do
      update_collection_with_comics(id, attrs, opts)
    else
      with {:ok, collection} <- get_collection(id, opts) do
        update_collection(collection, attrs, opts)
      end
    end
  end

  def update_collection_with_comics(collection_id, attrs, opts \\ []) do
    comics_to_add = Map.get(attrs, :comics_to_add, [])
    comics_to_remove = Map.get(attrs, :comics_to_remove, [])

    collection_attrs = Map.drop(attrs, [:comics_to_add, :comics_to_remove])

    with {:ok, collection} <- get_collection(collection_id, []) do
      Ecto.Multi.new()
      |> Ecto.Multi.update(:collection, Collection.changeset(collection, collection_attrs))
      |> add_comics_to_multi(collection_id, comics_to_add)
      |> remove_comics_from_multi(collection_id, comics_to_remove)
      |> Repo.transaction()
      |> case do
        {:ok, %{collection: updated_collection}} ->
          if opts[:preload] do
            get_collection(updated_collection.id, opts)
          else
            {:ok, updated_collection}
          end

        {:error, _failed_operation, changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  def add_to_collection(collection_ref, comic_ref, attrs \\ %{}, opts \\ [])

  def add_to_collection(%Collection{id: collection_id}, comics, attrs, _opts) when is_list(comics) do
    Enum.reduce(comics, Ecto.Multi.new(), fn comic, multi ->
      Ecto.Multi.insert(
        multi,
        System.monotonic_time(),
        CollectionComic.changeset(%CollectionComic{collection_id: collection_id, comic_id: comic.id}, attrs),
        on_conflict: :nothing
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, transactions} ->
        c_comics = transactions |> Map.values()
        {:ok, c_comics}

      e ->
        e
    end
  end

  def add_to_collection(%Collection{id: collection_id}, %Comic{id: comic_id}, attrs, opts) do
    add_to_collection(collection_id, comic_id, attrs, opts)
  end

  def add_to_collection(collection_id, comic_id, attrs, opts) when is_bitstring(collection_id) and is_bitstring(comic_id) do
    opts = Keyword.merge([repo_opts: [on_conflict: :nothing]], opts)

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
    case get_collection(collection_id) do
      {:ok, collection} -> Repo.delete(collection)
      error -> error
    end
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

  # Helper functions for comics operations in multi transactions
  defp add_comics_to_multi(multi, _collection_id, nil), do: multi
  defp add_comics_to_multi(multi, _collection_id, []), do: multi

  defp add_comics_to_multi(multi, collection_id, comic_ids) do
    existing_comic_ids = from(c in Comic, where: c.id in ^comic_ids, select: c.id) |> Repo.all()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    comic_attrs =
      Enum.map(existing_comic_ids, fn comic_id ->
        %{
          collection_id: collection_id,
          comic_id: comic_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    Ecto.Multi.insert_all(multi, :add_comics, CollectionComic, comic_attrs,
      on_conflict: :nothing,
      conflict_target: [:collection_id, :comic_id]
    )
  end

  defp remove_comics_from_multi(multi, _collection_id, nil), do: multi
  defp remove_comics_from_multi(multi, _collection_id, []), do: multi

  defp remove_comics_from_multi(multi, collection_id, comic_ids) do
    Ecto.Multi.delete_all(
      multi,
      :remove_comics,
      from(cc in CollectionComic,
        where: cc.collection_id == ^collection_id and cc.comic_id in ^comic_ids
      )
    )
  end

  def attrs, do: Collection.attrs()

  defp insert_collection(attrs, opts) do
    with {:ok, collection} <-
           %Collection{}
           |> Collection.changeset(attrs)
           |> Repo.insert(on_conflict: :nothing) do
      get_collection(collection.id, opts)
      |> case do
        {:error, :not_found} ->
          collection =
            list_collections(title: collection.title)
            |> Enum.at(0)

          if collection, do: {:ok, collection}, else: {:error, :not_found}

        other ->
          other
      end
    end
  end

  defp handle_insert_side_effects({:ok, collection}) do
    Processor.process(collection, [:insert])
    {:ok, collection}
  end

  defp handle_insert_side_effects(result), do: result

  defp reduce_collection_opts(query, opts) do
    {query, opts} = reduce_opts(query, opts)

    Enum.reduce(opts, query, fn
      {_any, ""}, query ->
        query

      {_any, nil}, query ->
        query

      {:search, search}, query ->
        search_term = "%#{search}%"

        where(query, [c], ilike(fragment("? || ' ' || COALESCE(?, '')", c.title, c.description), ^search_term))

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
