defmodule BasenjiWeb.ComicReaderLive.NavigationHelpers do
  @moduledoc """
  Helper functions for comic navigation logic.
  """

  @doc """
  Calculates the next page based on current page, total pages, and reading mode.
  """
  def next_page(current_page, total_pages, reading_mode) do
    increment = if reading_mode == "double", do: 2, else: 1
    min(current_page + increment, total_pages - 1)
  end

  @doc """
  Calculates the previous page based on current page and reading mode.
  """
  def prev_page(current_page, reading_mode) do
    decrement = if reading_mode == "double", do: 2, else: 1
    max(current_page - decrement, 0)
  end

  @doc """
  Validates and parses a page number input.
  """
  def parse_page_number(page_str, total_pages) do
    case Integer.parse(page_str) do
      {page, ""} when page >= 1 and page <= total_pages ->
        # Convert to 0-based indexing
        {:ok, page - 1}

      _ ->
        {:error, "Invalid page number"}
    end
  end

  @doc """
  Checks if navigation to next page is possible.
  """
  def can_go_next?(current_page, total_pages, reading_mode) do
    increment = if reading_mode == "double", do: 2, else: 1
    current_page + increment < total_pages
  end

  @doc """
  Checks if navigation to previous page is possible.
  """
  def can_go_prev?(current_page) do
    current_page > 0
  end
end
