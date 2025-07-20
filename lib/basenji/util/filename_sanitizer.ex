defmodule Basenji.FilenameSanitizer do
  @moduledoc false

  def sanitize(filename, opts \\ []) do
    opts = Keyword.merge([max_length: 80, remove_extension: true, preserve_case: false], opts)

    filename
    |> maybe_remove_extension(opts[:remove_extension])
    |> remove_all_parenthetical_content()
    |> remove_bash_problematic_chars()
    |> normalize_separators()
    |> maybe_normalize_case(opts[:preserve_case])
    |> trim_and_clean()
    |> truncate_intelligently(opts[:max_length])
    |> ensure_not_empty(filename)
  end

  defp maybe_remove_extension(filename, false), do: filename

  defp maybe_remove_extension(filename, true) do
    common_extensions = ~r/\.(pdf|epub|mobi|azw3?|cbz|cbr|cb7|cbt|zip|rar|7z|tar\.gz|tar|gz)$/i

    case Regex.run(common_extensions, filename) do
      nil -> filename
      [ext | _] -> String.slice(filename, 0, String.length(filename) - String.length(ext))
    end
  end

  defp remove_all_parenthetical_content(filename) do
    filename
    |> String.replace(~r/\([^)]*\)/, "")
    |> String.replace(~r/\[[^\]]*\]/, "")
    |> String.replace(~r/\{[^}]*\}/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp remove_bash_problematic_chars(filename) do
    filename
    |> String.replace(~r/['"'""''`´]/, "")
    |> String.replace(~r/[!@#$%^&*<>?\\|;:=+~]/, "")
    |> String.replace(~r/[\/\\:*?"<>|]/, "")
    |> String.replace(~r/[\x00-\x1f\x7f]/, "")
    |> String.replace(~r/[,;(){}[\]]/, "")
    |> normalize_unicode_to_ascii()
    |> String.replace(~r/[^a-zA-Z0-9\s.\-_]/, "")
  end

  defp normalize_unicode_to_ascii(filename) do
    filename
    |> String.replace(~r/[àáâãäå]/, "a")
    |> String.replace(~r/[èéêë]/, "e")
    |> String.replace(~r/[ìíîï]/, "i")
    |> String.replace(~r/[òóôõö]/, "o")
    |> String.replace(~r/[ùúûü]/, "u")
    |> String.replace(~r/[ýÿ]/, "y")
    |> String.replace(~r/[ñ]/, "n")
    |> String.replace(~r/[ç]/, "c")
    |> String.replace(~r/[ÀÁÂÃÄÅ]/, "A")
    |> String.replace(~r/[ÈÉÊË]/, "E")
    |> String.replace(~r/[ÌÍÎÏ]/, "I")
    |> String.replace(~r/[ÒÓÔÕÖ]/, "O")
    |> String.replace(~r/[ÙÚÛÜ]/, "U")
    |> String.replace(~r/[ÝŸ]/, "Y")
    |> String.replace(~r/[Ñ]/, "N")
    |> String.replace(~r/[Ç]/, "C")
  end

  defp normalize_separators(filename) do
    filename
    |> String.replace(~r/[-–—]{2,}/, "-")
    |> String.replace(~r/[.]{2,}/, ".")
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/[\s\-_.]+/, "_")
    |> String.replace(~r/_{2,}/, "_")
  end

  defp maybe_normalize_case(filename, true), do: filename
  defp maybe_normalize_case(filename, false), do: String.downcase(filename)

  defp trim_and_clean(filename) do
    filename
    |> String.trim()
    |> String.trim("_")
    |> String.trim(".")
    |> String.trim("_")
  end

  defp truncate_intelligently(filename, max_length) when byte_size(filename) <= max_length do
    filename
  end

  defp truncate_intelligently(filename, max_length) do
    if max_length <= 10 do
      String.slice(filename, 0, max_length)
    else
      truncated = String.slice(filename, 0, max_length)

      case String.reverse(truncated) |> String.split("_", parts: 2) do
        [_] ->
          truncated

        [_after_last, before_last] ->
          truncate_at_position(filename, truncated, String.length(before_last), max_length)
      end
    end
  end

  defp truncate_at_position(filename, truncated, index, max_length) do
    min_length = max(div(max_length * 7, 10), 15)

    if index >= min_length do
      String.slice(filename, 0, index)
    else
      truncated
    end
  end

  defp ensure_not_empty("", original_filename) do
    fallback =
      original_filename
      |> String.replace(~r/[^a-zA-Z0-9]/, "")
      |> String.slice(0, 20)
      |> String.downcase()

    if fallback == "", do: "file_#{System.unique_integer([:positive])}", else: fallback
  end

  defp ensure_not_empty(result, _), do: result
end
