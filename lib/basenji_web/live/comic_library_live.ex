defmodule BasenjiWeb.ComicLibraryLive do
  use BasenjiWeb, :live_view

  alias Basenji.Library

  require Logger

  @page_size 24

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :initial_scan)
    end

    {:ok,
     socket
     |> assign(:comics, [])
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> assign(:search_query, "")
     |> assign(:library_path, Library.get_library_path())
     |> assign(:page, 1)
     |> assign(:total_comics, 0)
     |> assign(:has_more, false)
     |> assign(:loading_more, false)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    if query != socket.assigns.search_query do
      send(self(), {:search, query})
      {:noreply, assign(socket, search_query: query, loading: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    send(self(), {:search, ""})
    {:noreply, assign(socket, search_query: "", loading: true)}
  end

  @impl true
  def handle_event("open_comic", %{"path" => path}, socket) do
    # Navigate to the comic reader with the selected comic
    {:noreply, push_navigate(socket, to: "/reader?comic=#{URI.encode(path)}&from=library")}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if not socket.assigns.loading_more and socket.assigns.has_more do
      send(self(), :load_more_comics)
      {:noreply, assign(socket, loading_more: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("rescan_library", _params, socket) do
    send(self(), :initial_scan)
    {:noreply, assign(socket, loading: true, error: nil)}
  end

  @impl true
  def handle_info(:initial_scan, socket) do
    try do
      # First get the count quickly
      total_comics = Library.count_comics()
      Logger.info("Total comics in library: #{total_comics}")

      # Load first page without thumbnails for speed
      comics = Library.quick_scan_library(limit: @page_size, sort_by: :title)

      # Add thumbnail URLs immediately (this is fast since it's just URL generation)
      comics_with_thumbnails =
        comics
        |> Enum.map(fn comic ->
          thumbnail_url = Library.generate_thumbnail_url(comic.path)
          Map.put(comic, :thumbnail, thumbnail_url)
        end)

      has_more = length(comics) >= @page_size

      {:noreply,
       socket
       |> assign(:comics, comics_with_thumbnails)
       |> assign(:loading, false)
       |> assign(:error, nil)
       |> assign(:total_comics, total_comics)
       |> assign(:page, 1)
       |> assign(:has_more, has_more)}
    rescue
      error ->
        Logger.error("Error scanning library: #{inspect(error)}")

        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, "Failed to scan library: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_info({:search, query}, socket) do
    try do
      comics =
        if query == "" do
          # Load all comics without search filter
          Library.quick_scan_library(limit: @page_size, sort_by: :title)
        else
          # Search through comics (this will be slower for large libraries)
          all_comics = Library.quick_scan_library(sort_by: :title)
          filter_comics(all_comics, query) |> Enum.take(@page_size)
        end

      # Add thumbnail URLs immediately
      comics_with_thumbnails =
        comics
        |> Enum.map(fn comic ->
          thumbnail_url = Library.generate_thumbnail_url(comic.path)
          Map.put(comic, :thumbnail, thumbnail_url)
        end)

      has_more = length(comics) >= @page_size and query == ""

      {:noreply,
       socket
       |> assign(:comics, comics_with_thumbnails)
       |> assign(:loading, false)
       |> assign(:page, 1)
       |> assign(:has_more, has_more)}
    rescue
      error ->
        Logger.error("Error searching library: #{inspect(error)}")
        {:noreply, assign(socket, loading: false, error: "Search failed")}
    end
  end

  @impl true
  def handle_info(:load_more_comics, socket) do
    try do
      next_page = socket.assigns.page + 1
      offset = (next_page - 1) * @page_size

      new_comics =
        if socket.assigns.search_query == "" do
          Library.quick_scan_library(
            limit: @page_size,
            offset: offset,
            sort_by: :title
          )
        else
          # For search, we need to get all and filter (not ideal for large libraries)
          all_comics = Library.quick_scan_library(sort_by: :title)

          filter_comics(all_comics, socket.assigns.search_query)
          |> Enum.drop(offset)
          |> Enum.take(@page_size)
        end

      # Add thumbnail URLs immediately
      new_comics_with_thumbnails =
        new_comics
        |> Enum.map(fn comic ->
          thumbnail_url = Library.generate_thumbnail_url(comic.path)
          Map.put(comic, :thumbnail, thumbnail_url)
        end)

      all_comics = socket.assigns.comics ++ new_comics_with_thumbnails
      has_more = length(new_comics) >= @page_size

      {:noreply,
       socket
       |> assign(:comics, all_comics)
       |> assign(:page, next_page)
       |> assign(:has_more, has_more)
       |> assign(:loading_more, false)}
    rescue
      error ->
        Logger.error("Error loading more comics: #{inspect(error)}")
        {:noreply, assign(socket, loading_more: false)}
    end
  end

  defp filter_comics(comics, query) when query == "" or is_nil(query) do
    comics
  end

  defp filter_comics(comics, query) do
    query_lower = String.downcase(query)

    Enum.filter(comics, fn comic ->
      String.contains?(String.downcase(comic.title), query_lower) or
        String.contains?(String.downcase(comic.filename), query_lower)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="bg-white shadow">
        <div class="mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="flex items-center">
              <.link
                navigate="/"
                class="flex items-center text-xl font-semibold text-gray-900 hover:text-indigo-600"
              >
                <svg class="w-6 h-6 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />
                </svg>
                Basenji
              </.link>
              <span class="mx-3 text-gray-400">/</span>
              <h1 class="text-xl font-semibold text-gray-900">Comic Library</h1>
              <span class="ml-3 text-sm text-gray-500">
                {@total_comics} comics
              </span>
            </div>
            <div class="flex items-center space-x-4">
              <!-- Search Bar -->
              <div class="relative">
                <input
                  type="text"
                  placeholder="Search comics..."
                  value={@search_query}
                  phx-change="search"
                  phx-value-query={@search_query}
                  class="w-64 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                />
                <%= if @search_query != "" do %>
                  <button
                    phx-click="clear_search"
                    class="absolute right-3 top-2.5 text-gray-400 hover:text-gray-600"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  </button>
                <% end %>
              </div>

              <button
                phx-click="rescan_library"
                class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                  />
                </svg>
                Rescan
              </button>
            </div>
          </div>
        </div>
      </header>

      <main class="mx-auto px-6 sm:px-8 lg:px-12 xl:px-16 py-10">
        <%= cond do %>
          <% @loading -> %>
            <div class="flex justify-center items-center h-64">
              <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
              <span class="ml-3 text-gray-600">Scanning library...</span>
            </div>
          <% @error -> %>
            <div class="bg-red-50 border border-red-200 rounded-md p-4">
              <div class="flex">
                <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                    clip-rule="evenodd"
                  />
                </svg>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-red-800">Error</h3>
                  <div class="mt-2 text-sm text-red-700">
                    {@error}
                  </div>
                  <div class="mt-2 text-sm text-red-600">
                    Library path: {@library_path}
                  </div>
                </div>
              </div>
            </div>
          <% length(@comics) == 0 and not @loading -> %>
            <div class="text-center py-12">
              <svg
                class="mx-auto h-12 w-12 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 7a2 2 0 012-2h10a2 2 0 012 2v2M5 11v6a2 2 0 002 2h10a2 2 0 002-2v-6"
                />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No comics found</h3>
              <p class="mt-1 text-sm text-gray-500">
                <%= if @search_query != "" do %>
                  No comics match your search query.
                <% else %>
                  No comic books were found in the library directory.
                <% end %>
              </p>
              <p class="mt-1 text-sm text-gray-400">
                Library path: {@library_path}
              </p>
            </div>
          <% true -> %>
            <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8 2xl:grid-cols-10 gap-8">
              <%= for comic <- @comics do %>
                <.comic_card comic={comic} />
              <% end %>
            </div>
            
    <!-- Load More Button -->
            <%= if @has_more do %>
              <div class="mt-8 text-center">
                <button
                  phx-click="load_more"
                  disabled={@loading_more}
                  class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 disabled:bg-gray-400 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  <%= if @loading_more do %>
                    <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                    Loading...
                  <% else %>
                    Load More Comics
                  <% end %>
                </button>
              </div>
            <% end %>
        <% end %>
      </main>
    </div>
    """
  end

  defp comic_card(assigns) do
    ~H"""
    <div
      phx-click="open_comic"
      phx-value-path={@comic.path}
      class="bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-300 cursor-pointer overflow-hidden group"
    >
      <div class="aspect-[3/4] bg-gray-200 relative overflow-hidden">
        <%= if @comic.thumbnail do %>
          <img
            src={@comic.thumbnail}
            alt={@comic.title}
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
            loading="lazy"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center bg-gray-300">
            <svg class="h-12 w-12 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 7a2 2 0 012-2h10a2 2 0 012 2v2M5 11v6a2 2 0 002 2h10a2 2 0 002-2v-6"
              />
            </svg>
          </div>
        <% end %>
        
    <!-- Hover overlay for better visual feedback -->
        <div class="absolute inset-0 bg-gradient-to-t from-black/30 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
        </div>
      </div>

      <div class="p-5 space-y-3">
        <h3
          class="text-sm font-semibold text-gray-900 line-clamp-2 leading-tight min-h-[2.5rem]"
          title={@comic.title}
        >
          {@comic.title}
        </h3>
        <div class="flex items-center justify-between">
          <p class="text-xs text-gray-500 font-medium">
            {Library.format_file_size(@comic.size)}
          </p>
          <div class="w-2 h-2 bg-green-400 rounded-full opacity-75"></div>
        </div>
      </div>
    </div>
    """
  end
end
