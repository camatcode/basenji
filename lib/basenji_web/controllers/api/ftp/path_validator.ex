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
      when root in [[], ["comics"], ["comics", "by-id"], ["comics", "by-title"], ["collections"], ["collections", "by-title"]] ->
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
    case subpath_segments do
      ["comics", invalid | _] when invalid not in ["by-id", "by-title"] -> :invalid
      _ -> :valid
    end
  end

  defp extract_refs(result, segments) do
    extract_refs_recursive(result, segments, 0)
  end

  defp extract_refs_recursive(result, segments, consumed_count) do
    case Enum.drop(segments, consumed_count) do
      ["collections", "by-title", title | _rest] when title != "" ->
        result
        |> Map.put(:collection_title, title)
        |> extract_refs_recursive(segments, consumed_count + 3)

      ["comics", "by-id", id | _rest] when id != "" ->
        {Map.put(result, :comic_id, Path.rootname(id)), consumed_count + 3}

      ["comics", "by-title", title | _rest] when title != "" ->
        {Map.put(result, :comic_title, Path.rootname(title)), consumed_count + 3}

      _other ->
        {result, consumed_count}
    end
  end

  defp extract_subpath(result, segments, consumed_count) do
    remaining_segments = Enum.drop(segments, consumed_count)

    subpath =
      case remaining_segments do
        [] ->
          nil

        subpath_segments ->
          if consumed_count == 0 do
            normalized_path = "/" <> Enum.join(segments, "/")
            if normalized_path not in @valid_roots, do: Enum.join(subpath_segments, "/")
          else
            Enum.join(subpath_segments, "/")
          end
      end

    Map.put(result, :subpath, subpath)
  end
end
