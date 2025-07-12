defmodule Basenji.FilenameSanitizer do
  @moduledoc """
  Aggressively sanitizes filenames to be safe for bash and filesystem operations.

  Removes anything that could cause issues: parentheses, quotes, special chars,
  and normalizes everything to simple alphanumeric + underscores.
  """

  @doc """
  Sanitizes a filename to be bash and filesystem safe.

  ## Options
    - `:max_length` - Maximum length (default: 80)
    - `:remove_extension` - Remove file extension (default: true)
    - `:preserve_case` - Keep original case (default: false)

  ## Examples

      iex> sanitize("My Comic (2023).cbz")
      "my_comic_2023"
      
      iex> sanitize("File with \"quotes\" & (parentheses).pdf")
      "file_with_quotes_parentheses"
  """
  def sanitize(filename, opts \\ []) do
    opts = Keyword.merge([max_length: 80, remove_extension: true, preserve_case: false], opts)

    filename
    |> remove_extension_if_requested(opts[:remove_extension])
    |> remove_all_parenthetical_content()
    |> remove_bash_problematic_chars()
    |> normalize_separators()
    |> normalize_case(opts[:preserve_case])
    |> trim_and_clean()
    |> truncate_intelligently(opts[:max_length])
    |> ensure_not_empty(filename)
  end

  @doc """
  Quick sanitization for simple cases.
  """
  def sanitize_simple(filename) do
    sanitize(filename, max_length: 50)
  end

  # Remove file extension if requested
  defp remove_extension_if_requested(filename, false), do: filename

  defp remove_extension_if_requested(filename, true) do
    # Only remove common file extensions, not parenthetical content
    common_extensions = ~r/\.(pdf|epub|mobi|azw3?|cbz|cbr|cb7|cbt|zip|rar|7z|tar\.gz|tar|gz)$/i

    case Regex.run(common_extensions, filename) do
      # No common extension found
      nil -> filename
      [ext | _] -> String.slice(filename, 0, String.length(filename) - String.length(ext))
    end
  end

  # Remove everything in parentheses - be aggressive
  defp remove_all_parenthetical_content(filename) do
    filename
    # Remove content in parentheses (including nested ones)
    |> String.replace(~r/\([^)]*\)/, "")
    # Remove content in square brackets
    |> String.replace(~r/\[[^\]]*\]/, "")
    # Remove content in curly braces
    |> String.replace(~r/\{[^}]*\}/, "")
    # Clean up multiple spaces that result from removals
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # Remove anything that could be problematic in bash or filesystems
  defp remove_bash_problematic_chars(filename) do
    filename
    # Remove all types of quotes and backticks
    |> String.replace(~r/['"'""''`´]/, "")
    # Remove bash special characters
    |> String.replace(~r/[!@#$%^&*<>?\\|;:=+~]/, "")
    # Remove filesystem problematic chars
    |> String.replace(~r/[\/\\:*?"<>|]/, "")
    # Remove control characters
    |> String.replace(~r/[\x00-\x1f\x7f]/, "")
    # Remove other punctuation except periods, dashes, and underscores
    |> String.replace(~r/[,;(){}[\]]/, "")
    # Convert accented characters to ASCII equivalents and keep only safe chars
    |> normalize_unicode_to_ascii()
    # Keep only ASCII alphanumeric, spaces, periods, dashes, and underscores
    |> String.replace(~r/[^a-zA-Z0-9\s.\-_]/, "")
  end

  # Convert common Unicode characters to ASCII equivalents
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

  # Normalize all separators to underscores
  defp normalize_separators(filename) do
    filename
    # Convert multiple dashes/dots/spaces to single separators
    |> String.replace(~r/[-–—]{2,}/, "-")
    |> String.replace(~r/[.]{2,}/, ".")
    |> String.replace(~r/\s+/, " ")
    # Convert spaces, dashes, and dots to underscores
    |> String.replace(~r/[\s\-_.]+/, "_")
    # Remove multiple consecutive underscores
    |> String.replace(~r/_{2,}/, "_")
  end

  # Normalize case
  defp normalize_case(filename, true), do: filename
  defp normalize_case(filename, false), do: String.downcase(filename)

  # Trim underscores and whitespace from ends
  defp trim_and_clean(filename) do
    filename
    |> String.trim()
    |> String.trim("_")
    |> String.trim(".")
    # Trim again in case there were trailing dots before underscores
    |> String.trim("_")
  end

  # Intelligent truncation at word boundaries
  defp truncate_intelligently(filename, max_length) when byte_size(filename) <= max_length do
    filename
  end

  defp truncate_intelligently(filename, max_length) do
    if max_length <= 10 do
      String.slice(filename, 0, max_length)
    else
      # Try to break at underscore near the end
      truncated = String.slice(filename, 0, max_length)

      case String.reverse(truncated) |> String.split("_", parts: 2) do
        [_] ->
          truncated

        [_after_last, before_last] ->
          index = String.length(before_last)
          # At least 70% or 15 chars
          min_length = max(div(max_length * 7, 10), 15)

          if index >= min_length do
            String.slice(filename, 0, index)
          else
            truncated
          end
      end
    end
  end

  # Ensure we don't end up with an empty string
  defp ensure_not_empty("", original_filename) do
    # Fallback: use first few alphanumeric characters
    fallback =
      original_filename
      |> String.replace(~r/[^a-zA-Z0-9]/, "")
      |> String.slice(0, 20)
      |> String.downcase()

    if fallback == "", do: "file_#{System.unique_integer([:positive])}", else: fallback
  end

  defp ensure_not_empty(result, _), do: result

  @doc """
  Sanitizes a filename specifically for use as a temporary directory name.
  Shorter and more aggressive sanitization.
  """
  def sanitize_for_temp_dir(filename) do
    sanitize(filename, max_length: 50, remove_extension: true, preserve_case: false)
  end

  @doc """
  Generates a unique directory name based on the filename.
  Appends a timestamp or counter if needed to ensure uniqueness.
  """
  def sanitize_unique(filename, existing_names \\ []) do
    base = sanitize(filename)

    if base in existing_names do
      add_unique_suffix(base, existing_names)
    else
      base
    end
  end

  defp add_unique_suffix(base, existing_names, counter \\ 1) do
    candidate = "#{base}_#{counter}"

    if candidate in existing_names do
      add_unique_suffix(base, existing_names, counter + 1)
    else
      candidate
    end
  end
end
