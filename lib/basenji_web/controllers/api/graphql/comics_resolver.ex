defmodule BasenjiWeb.GraphQL.ComicsResolver do
  @moduledoc false
  alias Basenji.Comics
  alias BasenjiWeb.GraphQL.GraphQLUtils

  @preload_mapping %{
    "memberCollections" => :member_collections,
    "originalComic" => :original_comic,
    "optimizedComic" => :optimized_comic
  }

  def list_comics(_root, args, info) do
    preload_opts = GraphQLUtils.extract_preloads(info, @preload_mapping)

    # Add nested preloads for any requested nested relationships
    enhanced_preloads = enhance_preloads_with_nested_relationships(info, preload_opts)

    opts = Map.to_list(args) ++ enhanced_preloads

    comics =
      Comics.list_comics(opts)
      |> set_image_preview()
      |> set_pages()
      |> set_optimization_flags()

    {:ok, comics}
  end

  def create_comic(_root, %{input: attrs}, info) do
    case Comics.create_comic(attrs) do
      {:ok, comic} -> maybe_preload_and_process_comic(comic, info)
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def get_comic(_root, %{id: id} = args, info) do
    preload_opts = GraphQLUtils.extract_preloads(info, @preload_mapping)
    opts = Map.to_list(args) ++ preload_opts

    case Comics.get_comic(id, opts) do
      {:ok, comic} ->
        processed_comic = comic |> set_image_preview() |> set_pages() |> set_optimization_flags()
        {:ok, processed_comic}

      error ->
        GraphQLUtils.handle_result(error)
    end
  end

  def update_comic(_root, %{id: id, input: attrs}, info) do
    case Comics.update_comic(id, attrs) do
      {:ok, comic} -> maybe_preload_and_process_comic(comic, info)
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def delete_comic(_root, %{id: id}, _info) do
    case Comics.delete_comic(id) do
      {:ok, _deleted} -> {:ok, true}
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def formats, do: Comics.formats()

  def order_by_attrs, do: Comics.attrs() -- [:image_preview]

  defp set_pages(comics) when is_list(comics) do
    comics
    |> Enum.map(&set_pages/1)
  end

  defp set_pages(%{page_count: page_count} = comic) when page_count <= 0, do: comic

  defp set_pages(%{page_count: page_count} = comic) do
    pages = 1..page_count |> Enum.map(fn page_num -> "/api/comics/#{comic.id}/page/#{page_num}" end)

    comic
    |> Map.put(:pages, pages)
  end

  defp set_image_preview(comics) when is_list(comics) do
    comics
    |> Enum.map(&set_image_preview/1)
  end

  defp set_image_preview(%{image_preview: nil} = comic), do: comic

  defp set_image_preview(comic) do
    Map.put(comic, :image_preview, "/api/comics/#{comic.id}/preview")
  end

  defp set_optimization_flags(comics) when is_list(comics) do
    comics
    |> Enum.map(&set_optimization_flags/1)
  end

  defp set_optimization_flags(comic) do
    comic
    |> Map.put(:is_optimized, not is_nil(comic.original_id))
    |> Map.put(:has_optimization, not is_nil(comic.optimized_id))
  end

  defp enhance_preloads_with_nested_relationships(info, base_preloads) do
    # Build nested preloads based on GraphQL query structure
    nested_preloads = build_nested_preloads(info)

    case {Keyword.get(base_preloads, :preload, []), nested_preloads} do
      {[], []} ->
        base_preloads

      {_existing, []} ->
        base_preloads

      {[], nested} ->
        [preload: nested]

      {existing, nested} ->
        # Merge existing and nested preloads
        merged = merge_preloads(existing, nested)
        [preload: merged]
    end
  end

  defp build_nested_preloads(%{definition: %{selections: selections}}) do
    selections
    |> Enum.flat_map(&extract_nested_preloads/1)
    |> Enum.reject(&is_nil/1)
  end

  defp build_nested_preloads(_), do: []

  defp extract_nested_preloads(%{name: field_name, selections: nested_selections}) do
    case @preload_mapping[field_name] do
      nil ->
        []

      preload_key ->
        nested_fields =
          Enum.map(nested_selections, &@preload_mapping[&1.name])
          |> Enum.reject(&is_nil/1)

        if Enum.empty?(nested_fields) do
          [preload_key]
        else
          [{preload_key, nested_fields}]
        end
    end
  end

  defp extract_nested_preloads(_), do: []

  defp merge_preloads(existing, nested) do
    # For now, just combine them - could be more sophisticated
    existing ++ nested
  end

  defp maybe_preload_and_process_comic(comic, info) do
    preload_opts = GraphQLUtils.extract_preloads(info, @preload_mapping)

    case {Enum.empty?(preload_opts), preload_opts} do
      {true, _} ->
        processed_comic = comic |> set_image_preview() |> set_pages() |> set_optimization_flags()
        {:ok, processed_comic}

      {false, preload_opts} ->
        case Comics.get_comic(comic.id, preload_opts) do
          {:ok, preloaded_comic} ->
            processed_comic = preloaded_comic |> set_image_preview() |> set_pages() |> set_optimization_flags()
            {:ok, processed_comic}

          error ->
            GraphQLUtils.handle_result(error)
        end
    end
  end
end
