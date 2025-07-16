defmodule Basenji.Comics do
  @moduledoc false

  import Basenji.ContextUtils
  import Ecto.Query, warn: false

  alias Basenji.Comic
  alias Basenji.Processor
  alias Basenji.Reader
  alias Basenji.Repo

  def from_resource(location, attrs \\ %{}, opts \\ []) do
    attrs |> Map.put(:resource_location, location) |> create_comic(opts)
  end

  def create_comic(attrs, opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    insert_comic(attrs, opts)
    |> handle_insert_side_effects()
  end

  def create_comics(attrs_list, _opts \\ []) when is_list(attrs_list) do
    Enum.reduce(attrs_list, Ecto.Multi.new(), fn attrs, multi ->
      Ecto.Multi.insert(multi, System.monotonic_time(), Comic.changeset(%Comic{}, attrs), on_conflict: :nothing)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, transactions} ->
        comics =
          Map.values(transactions)
          |> Enum.map(fn comic -> list_comics(resource_location: comic.resource_location) |> hd() end)

        handle_insert_side_effects({:ok, comics})

      e ->
        e
    end
  end

  def list_comics(opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    Comic
    |> reduce_comic_opts(opts)
    |> Repo.all(opts[:repo_opts])
  end

  def get_comic(id, opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    from(c in Comic, where: c.id == ^id)
    |> reduce_comic_opts(opts)
    |> Repo.one(opts[:repo_opts])
    |> case do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  def update_comic(%Comic{} = comic, attrs) do
    comic
    |> Comic.update_changeset(attrs)
    |> Repo.update()
  end

  def update_comic(id, attrs) when is_bitstring(id) do
    with {:ok, comic} <- get_comic(id) do
      update_comic(comic, attrs)
    end
  end

  def delete_comic(comic_ref, opts \\ [])

  def delete_comic(nil, _opts), do: nil

  def delete_comic(comic_id, opts) when is_binary(comic_id) do
    case get_comic(comic_id) do
      {:ok, comic} -> delete_comic(comic, opts)
      error -> error
    end
  end

  def delete_comic(%Comic{id: _comic_id} = comic, opts) do
    opts = Keyword.merge([delete_resource: false], opts)

    if opts[:delete_resource] == true do
      Processor.process(comic, [:delete])
    end

    Repo.delete(comic)
  end

  def stream_pages(ref, opts \\ [])

  def stream_pages(nil, _opts), do: {:error, :not_found}

  def stream_pages(%Comic{resource_location: loc, optimized_id: optimized_id}, opts) do
    should_optimize? = optimized_id == nil
    opts = Keyword.merge([optimize: should_optimize?], opts)
    Reader.stream_pages(loc, opts)
  end

  def stream_pages(comic_id, opts) when is_bitstring(comic_id) do
    with {:ok, comic} <- get_comic(comic_id) do
      stream_pages(comic, opts)
    end
  end

  def get_page(comic, page_num, opts \\ [])

  def get_page(nil, _, _), do: {:error, :not_found}

  def get_page(%Comic{page_count: page_count}, page_num, _opts)
      when page_count != -1 and (page_num < 0 or page_num > page_count),
      do: {:error, :not_found}

  def get_page(%Comic{resource_location: loc, optimized_id: optimized_id} = _comic, page_num, opts) do
    should_optimize? = optimized_id == nil
    opts = Keyword.merge([optimize: should_optimize?], opts)

    with {:ok, %{entries: entries}} <- Reader.read(loc, opts) do
      entry = Enum.at(entries, page_num - 1)

      mime = MIME.from_path(entry.file_name)

      bytes = entry.stream_fun.() |> Enum.to_list() |> :binary.list_to_bin()

      {:ok, bytes, mime}
    end
  end

  def get_page(comic_id, page_num, opts) when is_bitstring(comic_id) do
    with {:ok, comic} <- get_comic(comic_id) do
      get_page(comic, page_num, opts)
    end
  end

  def get_image_preview(comic_ref)

  def get_image_preview(%Comic{image_preview: nil}) do
    {:error, :no_preview}
  end

  def get_image_preview(%Comic{image_preview: bytes}) do
    {:ok, bytes}
  end

  def get_image_preview(comic_id) when is_bitstring(comic_id) do
    with {:ok, comic} <- get_comic(comic_id) do
      get_image_preview(comic)
    end
  end

  def count_comics(opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    Comic
    |> reduce_comic_opts(opts)
    |> Repo.aggregate(:count, :id)
  end

  def formats, do: Comic.formats()

  def comic_attrs, do: Comic.attrs()

  def create_optimized_comic(original_comic, optimized_attrs) do
    # Ensure we have the original comic with collections preloaded
    {:ok, original_with_collections} = get_comic(original_comic.id, preload: [:member_collections])

    # Clone attributes from original comic
    attrs = Comic.clone_attrs(original_comic, optimized_attrs)

    with {:ok, optimized_comic} <- create_comic(attrs) do
      # Copy collection relationships from original to optimized
      Enum.each(original_with_collections.member_collections, fn collection ->
        Basenji.Collections.add_to_collection(collection.id, optimized_comic.id)
      end)

      # Update original to point to optimized version
      case update_comic(original_comic, %{optimized_id: optimized_comic.id}) do
        {:ok, _updated_original} -> {:ok, optimized_comic}
        error -> error
      end
    end
  end

  def get_preferred_comic(comic_id, opts \\ []) do
    opts = Keyword.merge([prefer_optimized: true], opts)

    with {:ok, comic} <- get_comic(comic_id, preload: [:optimized_comic]) do
      if opts[:prefer_optimized] && comic.optimized_comic do
        {:ok, comic.optimized_comic}
      else
        {:ok, comic}
      end
    end
  end

  def revert_optimization(comic_id) do
    with {:ok, comic} <- get_comic(comic_id, preload: [:original_comic]) do
      cond do
        comic.original_id ->
          case update_comic(comic.original_comic, %{optimized_id: nil}) do
            {:ok, original} ->
              delete_comic(comic)
              {:ok, original}

            error ->
              error
          end

        not is_nil(Map.get(comic, :optimized_id)) ->
          optimized_id = Map.get(comic, :optimized_id)

          {1, nil} =
            Repo.update_all(
              from(c in Comic, where: c.id == ^optimized_id),
              set: [original_id: nil]
            )

          update_comic(comic, %{optimized_id: nil})

        true ->
          {:error, "Comic has no optimization to revert"}
      end
    end
  end

  defp handle_insert_side_effects({:ok, comic}) do
    Processor.process(comic, [:insert])
    {:ok, comic}
  end

  defp handle_insert_side_effects(result), do: result

  defp insert_comic(attrs, opts) do
    with {:ok, comic} <-
           %Comic{}
           |> Comic.changeset(attrs)
           |> Repo.insert(on_conflict: :nothing) do
      get_comic(comic.id, opts)
      |> case do
        {:error, :not_found} ->
          comic =
            list_comics(resource_location: comic.resource_location)
            |> Enum.at(0)

          if comic, do: {:ok, comic}, else: {:error, :not_found}

        other ->
          other
      end
    end
  end

  defp reduce_comic_opts(query, opts) do
    {q, opts} = reduce_opts(query, opts)

    Enum.reduce(opts, q, fn
      {_any, ""}, query ->
        query

      {_any, nil}, query ->
        query

      {:prefer_optimized, true}, query ->
        where(query, [c], is_nil(c.optimized_id))

      {:search, search}, query ->
        search_term = "%#{search}%"

        where(
          query,
          [c],
          ilike(
            fragment("? || ' ' || COALESCE(?, '') || ' ' || COALESCE(?, '')", c.title, c.author, c.description),
            ^search_term
          )
        )

      {:title, search}, query ->
        term = "%#{search}%"
        where(query, [s], ilike(s.title, ^term))

      {:author, search}, query ->
        term = "%#{search}%"
        where(query, [s], ilike(s.author, ^term))

      {:description, search}, query ->
        term = "%#{search}%"
        where(query, [s], ilike(s.description, ^term))

      {:resource_location, loc}, query ->
        where(query, [c], c.resource_location == ^loc)

      {:released_year, yr}, query ->
        where(query, [c], c.released_year == ^yr)

      {:format, fmt}, query ->
        where(query, [c], c.format == ^fmt)

      _, query ->
        query
    end)
  end
end
