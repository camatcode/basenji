defmodule Basenji.Comics do
  @moduledoc false
  use Basenji.TelemetryHelpers

  import Basenji.ContextUtils
  import Ecto.Query, warn: false

  alias Basenji.Comics.Comic
  alias Basenji.Comics.ComicPreview
  alias Basenji.ObanProcessor
  alias Basenji.Reader
  alias Basenji.Repo

  def from_resource(location, attrs \\ %{}, opts \\ []) do
    attrs |> Map.put(:resource_location, location) |> create_comic(opts)
  end

  def create_comic(attrs, opts \\ []) do
    meter_duration [:basenji, :command], "create_comic" do
      opts = Keyword.merge([repo_opts: []], opts)

      insert_comic(attrs, opts)
      |> handle_insert_side_effects()
    end
  end

  def create_comics(attrs_list, _opts \\ []) when is_list(attrs_list) do
    meter_duration [:basenji, :command], "create_comics" do
      Enum.reduce(attrs_list, Ecto.Multi.new(), fn attrs, multi ->
        Ecto.Multi.insert(multi, System.monotonic_time(), Comic.changeset(%Comic{}, attrs), on_conflict: :nothing)
      end)
      |> Repo.transaction()
      |> case do
        {:ok, transactions} ->
          comics = determine_comics_from_transactions(transactions)

          handle_insert_side_effects({:ok, comics})

        e ->
          e
      end
    end
  end

  def list_comics(opts \\ []) do
    meter_duration [:basenji, :query], "list_comics" do
      opts = Keyword.merge([repo_opts: []], opts)

      Comic
      |> reduce_comic_opts(opts)
      |> Repo.all(opts[:repo_opts])
    end
  end

  def get_comic(id, opts \\ []) do
    meter_duration [:basenji, :query], "get_comic" do
      opts = Keyword.merge([repo_opts: []], opts)

      from(c in Comic, where: c.id == ^id)
      |> reduce_comic_opts(opts)
      |> Repo.one(opts[:repo_opts])
      |> case do
        nil -> {:error, :not_found}
        result -> {:ok, result}
      end
    end
  end

  def update_comic(%Comic{} = comic, attrs) do
    meter_duration [:basenji, :command], "update_comic" do
      comic
      |> Comic.update_changeset(attrs)
      |> Repo.update()
    end
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
    meter_duration [:basenji, :command], "delete_comic" do
      opts = Keyword.merge([delete_resource: false], opts)

      if opts[:delete_resource] == true do
        ObanProcessor.process(comic, [:delete])
      end

      Repo.delete(comic)
    end
  end

  def stream_pages(ref, opts \\ [])

  def stream_pages(nil, _opts), do: {:error, :not_found}

  def stream_pages(%Comic{resource_location: loc, optimized_id: optimized_id, pre_optimized?: pre_optimized?}, opts) do
    should_optimize? = optimized_id == nil && !pre_optimized?

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

  def get_page(
        %Comic{resource_location: loc, optimized_id: optimized_id, pre_optimized?: pre_optimized?} = _comic,
        page_num,
        opts
      ) do
    meter_duration [:basenji, :query], "get_page" do
      should_optimize? = optimized_id == nil && !pre_optimized?
      opts = Keyword.merge([optimize: should_optimize?], opts)

      with {:ok, %{entries: entries}} <- Reader.read(loc, opts) do
        entry = Enum.at(entries, page_num - 1)

        mime = MIME.from_path(entry.file_name)

        bytes = entry.stream_fun.() |> Enum.to_list() |> :binary.list_to_bin()

        {:ok, bytes, mime}
      end
    end
  end

  def get_page(comic_id, page_num, opts) when is_bitstring(comic_id) do
    with {:ok, comic} <- get_comic(comic_id) do
      get_page(comic, page_num, opts)
    end
  end

  def get_image_preview(comic_ref)

  def get_image_preview(%Comic{id: comic_id}) do
    case Repo.get_by(ComicPreview, comic_id: comic_id) do
      nil -> {:error, :no_preview}
      preview -> {:ok, preview.image_data}
    end
  end

  def get_image_preview(comic_id) when is_bitstring(comic_id) do
    with {:ok, comic} <- get_comic(comic_id) do
      get_image_preview(comic)
    end
  end

  def associate_image_preview(%Comic{id: id} = comic, bytes, assoc_opts \\ []) do
    content_type = Keyword.get(assoc_opts, :content_type, "image/jpeg")
    width = Keyword.get(assoc_opts, :width, nil)
    height = Keyword.get(assoc_opts, :height, nil)

    attrs = %{
      comic_id: id,
      image_data: bytes,
      content_type: content_type,
      width: width,
      height: height
    }

    with {:ok, preview} <-
           %ComicPreview{}
           |> ComicPreview.changeset(attrs)
           |> Repo.insert(on_conflict: :replace_all, conflict_target: :comic_id),
         {:ok, _} <- update_comic(comic, %{image_preview_id: preview.id}) do
      {:ok, preview}
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

  def get_hash(comic_id) when is_bitstring(comic_id) do
    with {:ok, comic} <- get_comic(comic_id) do
      get_hash(comic)
    end
  end

  def get_hash(%{hash: hash}) when is_bitstring(hash), do: hash

  def get_hash(%Comic{} = comic), do: hash_content(comic)

  defp hash_content(comic) do
    {:ok, stream} = stream_pages(comic, optimize: false)

    h64_stream = :xxh3.new()

    stream
    |> Enum.each(fn page_stream ->
      bin_list = page_stream |> Enum.to_list() |> :erlang.iolist_to_binary()
      :xxh3.update(h64_stream, bin_list)
    end)

    result = :xxh3.digest(h64_stream)

    {:ok, "#{result}"}
  end

  defp handle_insert_side_effects({:ok, comic}) do
    ObanProcessor.process(comic, [:insert])
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

  defp determine_comics_from_transactions(transactions) do
    Map.values(transactions)
    |> Enum.map(fn comic ->
      list_comics(resource_location: comic.resource_location)
      |> case do
        [] -> nil
        other -> hd(other)
      end
    end)
    |> Enum.filter(&Function.identity/1)
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

      {:hash, hash}, query ->
        where(query, [c], c.hash == ^hash)

      _, query ->
        query
    end)
  end
end
