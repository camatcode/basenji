defmodule BasenjiWeb.FTP.PathValidator do
  @moduledoc false

  @valid_roots [
    "/",
    "/comics",
    "/comics/by-id",
    "/comics/by-title",
    "/collections",
    "/collections/by-title"
  ]

  def parse_path(path) when is_binary(path) do
    normalized_path = normalize_path(path)
    segments = String.split(normalized_path, "/", trim: true)

    case validate_path_structure(segments) do
      :valid ->
        result = %{path: path, is_directory: String.ends_with?(path, "/")}
        {result_with_refs, consumed_count} = extract_refs(result, segments)
        final_result = extract_subpath(result_with_refs, segments, consumed_count)
        {:ok, final_result}

      :invalid ->
        {:error, :invalid_path}
    end
  end

  def valid_root_directory?(path) when is_binary(path) do
    case parse_path(path) do
      {:ok, _result} -> true
      {:error, _reason} -> false
    end
  end

  defp normalize_path(path) do
    path
    |> String.replace("//", "/")
    |> String.trim_trailing("/")
    |> case do
      "" -> "/"
      normalized -> normalized
    end
  end

  defp validate_path_structure(segments) do
    segments
    |> case do
      root
      when root in [
             [],
             ["comics"],
             ["comics", "by-id"],
             ["comics", "by-title"],
             ["collections"],
             ["collections", "by-title"]
           ] ->
        :valid

      ["comics", "by-id", id | _rest] when id != "" ->
        :valid

      ["comics", "by-title", title | _rest] when title != "" ->
        :valid

      ["collections", "by-title", title | rest] when title != "" ->
        validate_collection_subpath(rest)

      _ ->
        :invalid
    end
  end

  defp validate_collection_subpath(subpath_segments) do
    validate_collection_subpath_recursive(subpath_segments)
  end

  defp validate_collection_subpath_recursive(subpath_segments) do
    case subpath_segments do
      [] -> :valid
      ["comics" | rest] -> validate_comics_path(rest)
      [title | rest] when title != "" -> validate_collection_subpath_recursive(rest)
      _ -> :invalid
    end
  end

  defp validate_comics_path([]), do: :valid
  defp validate_comics_path(["by-id"]), do: :valid
  defp validate_comics_path(["by-title"]), do: :valid
  defp validate_comics_path(["by-id", _id | _rest]), do: :valid
  defp validate_comics_path(["by-title", _title | _rest]), do: :valid
  defp validate_comics_path([invalid | _]) when invalid not in ["by-id", "by-title"], do: :invalid
  defp validate_comics_path(_), do: :valid

  defp extract_refs(result, segments) do
    extract_refs_recursive(result, segments, 0)
  end

  defp extract_refs_recursive(result, segments, consumed_count) do
    remaining_segments = Enum.drop(segments, consumed_count)

    case remaining_segments do
      ["collections", "by-title", title | rest] when title != "" ->
        handle_collections_by_title(result, segments, consumed_count, title, rest)

      [title | rest] when title != "" and title != "comics" ->
        handle_collection_title(result, segments, consumed_count, title, rest)

      ["comics", "by-id", id | _rest] when id != "" ->
        {Map.put(result, :comic_id, Path.rootname(id)), consumed_count + 3}

      ["comics", "by-title", title | _rest] when title != "" ->
        {Map.put(result, :comic_title, Path.rootname(title)), consumed_count + 3}

      _other ->
        {result, consumed_count}
    end
  end

  defp handle_collections_by_title(result, segments, consumed_count, title, rest) do
    updated_result = Map.put(result, :collection_title, title)

    case rest do
      ["comics" | _] ->
        extract_refs_recursive(updated_result, segments, consumed_count + 3)

      [next_title | _] when next_title != "" and next_title != "comics" ->
        extract_refs_recursive(updated_result, segments, consumed_count + 3)

      _ ->
        {updated_result, consumed_count + 3}
    end
  end

  defp handle_collection_title(result, segments, consumed_count, title, rest) do
    case rest do
      ["comics" | _] ->
        updated_result = Map.put(result, :collection_title, title)
        extract_refs_recursive(updated_result, segments, consumed_count + 1)

      [next_title | _] when next_title != "" and next_title != "comics" ->
        updated_result = Map.put(result, :collection_title, title)
        extract_refs_recursive(updated_result, segments, consumed_count + 1)

      [] ->
        {Map.put(result, :collection_title, title), consumed_count + 1}

      _ ->
        {result, consumed_count}
    end
  end

  defp extract_subpath(result, segments, consumed_count) do
    remaining_segments = Enum.drop(segments, consumed_count)
    subpath = build_subpath(remaining_segments, segments, consumed_count)
    Map.put(result, :subpath, subpath)
  end

  defp build_subpath([], _segments, _consumed_count), do: nil

  defp build_subpath(subpath_segments, segments, 0) do
    normalized_path = "/" <> Enum.join(segments, "/")
    if normalized_path not in @valid_roots, do: Enum.join(subpath_segments, "/")
  end

  defp build_subpath(subpath_segments, _segments, _consumed_count) do
    Enum.join(subpath_segments, "/")
  end
end
