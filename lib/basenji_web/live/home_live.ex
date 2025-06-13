defmodule BasenjiWeb.HomeLive do
  use BasenjiWeb, :live_view

  alias Basenji.Library

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Load comic count immediately, then load recent comics
      send(self(), :load_comic_count)
      send(self(), :load_recent_comics)
    end

    {:ok,
     socket
     |> assign(:recent_comics, [])
     |> assign(:loading_recent, true)
     |> assign(:loading_count, true)
     |> assign(:total_comics, 0)
     |> assign(:library_path, Library.get_library_path())}
  end

  @impl true
  def handle_event("open_comic", %{"path" => path}, socket) do
    {:noreply, push_navigate(socket, to: "/reader?comic=#{URI.encode(path)}&from=library")}
  end

  @impl true
  def handle_info(:load_comic_count, socket) do
    try do
      total_comics = Library.count_comics()
      Logger.info("Found #{total_comics} total comics in library")

      {:noreply,
       socket
       |> assign(:total_comics, total_comics)
       |> assign(:loading_count, false)}
    rescue
      error ->
        Logger.error("Error counting comics: #{inspect(error)}")
        {:noreply, assign(socket, loading_count: false)}
    end
  end

  @impl true
  def handle_info(:load_recent_comics, socket) do
    try do
      # Load recent comics without thumbnails first for speed, limit to 6
      recent_comics =
        Library.quick_scan_library(
          limit: 6,
          sort_by: :modified_at
        )

      # Then load thumbnails for just these comics in the background
      comics_with_thumbnails =
        recent_comics
        |> Enum.map(fn comic ->
          # Generate thumbnail URL instead of processing the image
          thumbnail_url = Library.generate_thumbnail_url(comic.path)
          Map.put(comic, :thumbnail, thumbnail_url)
        end)

      {:noreply,
       socket
       |> assign(:recent_comics, comics_with_thumbnails)
       |> assign(:loading_recent, false)}
    rescue
      error ->
        Logger.error("Error loading recent comics: #{inspect(error)}")
        {:noreply, assign(socket, loading_recent: false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <div class="min-h-screen bg-gray-50">
      <!-- Hero Section -->
      <div class="relative overflow-hidden">
        <div class="absolute inset-0">
          <div class="absolute inset-0 bg-gradient-to-br from-indigo-600 to-purple-700"></div>
        </div>
        <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24">
          <div class="text-center">
            <h1 class="text-4xl md:text-6xl font-bold text-white mb-6">
              Basenji Comic Reader
            </h1>
            <p class="text-xl text-indigo-100 mb-8 max-w-3xl mx-auto">
              A modern, self-hostable comic reader supporting CBZ, CBR, CB7, and CBT formats.
              Built with Phoenix LiveView for a smooth, interactive reading experience.
            </p>
            <div class="flex flex-col sm:flex-row items-center justify-center space-y-4 sm:space-y-0 sm:space-x-4">
              <.link
                navigate="/library"
                class="inline-flex items-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-indigo-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
              >
                <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />
                </svg>
                Browse Comic Library
              </.link>
              <.link
                navigate="/reader"
                class="inline-flex items-center px-8 py-3 border border-white text-base font-medium rounded-md text-white bg-transparent hover:bg-white hover:text-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-white transition-colors"
              >
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                  />
                </svg>
                Upload Comic
              </.link>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Stats Section -->
      <div class="bg-white">
        <div class="mx-auto px-6 sm:px-8 lg:px-12 xl:px-16 py-12">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-8 text-center">
            <div>
              <div class="text-3xl font-bold text-indigo-600">
                <%= if @loading_count do %>
                  <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600 mx-auto">
                  </div>
                <% else %>
                  {@total_comics}
                <% end %>
              </div>
              <div class="text-sm text-gray-500">Comics in Library</div>
            </div>
            <div>
              <div class="text-3xl font-bold text-indigo-600">4</div>
              <div class="text-sm text-gray-500">Supported Formats</div>
            </div>
            <div>
              <div class="text-3xl font-bold text-indigo-600">✨</div>
              <div class="text-sm text-gray-500">Modern Interface</div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Recent Comics Section -->
      <%= if @total_comics > 0 do %>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div class="flex items-center justify-between mb-8">
            <div>
              <h2 class="text-3xl font-bold text-gray-900">Recently Added</h2>
              <p class="text-gray-600 mt-2">Latest comics in your library</p>
            </div>
            <.link
              navigate="/library"
              class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              View All
              <svg class="ml-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 5l7 7-7 7"
                />
              </svg>
            </.link>
          </div>

          <%= if @loading_recent do %>
            <div class="flex justify-center items-center h-48">
              <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
              <span class="ml-3 text-gray-600">Loading recent comics...</span>
            </div>
          <% else %>
            <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8 2xl:grid-cols-10 gap-8">
              <%= for comic <- @recent_comics do %>
                <.comic_card comic={comic} />
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="mx-auto px-6 sm:px-8 lg:px-12 xl:px-16 py-16">
          <div class="text-center">
            <svg
              class="mx-auto h-24 w-24 text-gray-400"
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
            <h3 class="mt-6 text-lg font-medium text-gray-900">No comics found</h3>
            <p class="mt-2 text-gray-500 max-w-md mx-auto">
              Add some comic books to your library directory to get started.
            </p>
            <p class="mt-1 text-sm text-gray-400">
              Library path: {@library_path}
            </p>
            <div class="mt-8 flex flex-col sm:flex-row items-center justify-center space-y-4 sm:space-y-0 sm:space-x-4">
              <.link
                navigate="/reader"
                class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                  />
                </svg>
                Upload a Comic
              </.link>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Features Section -->
      <div class="bg-gray-100">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div class="text-center mb-12">
            <h2 class="text-3xl font-bold text-gray-900">Features</h2>
            <p class="text-gray-600 mt-2">
              Everything you need for the perfect comic reading experience
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            <div class="text-center">
              <div class="w-16 h-16 mx-auto bg-indigo-100 rounded-lg flex items-center justify-center mb-4">
                <svg class="w-8 h-8 text-indigo-600" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">Multiple Formats</h3>
              <p class="text-gray-600">Support for CBZ, CBR, CB7, and CBT comic book formats</p>
            </div>

            <div class="text-center">
              <div class="w-16 h-16 mx-auto bg-indigo-100 rounded-lg flex items-center justify-center mb-4">
                <svg
                  class="w-8 h-8 text-indigo-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"
                  />
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">Reading Modes</h3>
              <p class="text-gray-600">
                Single page and double page reading modes for optimal viewing
              </p>
            </div>

            <div class="text-center">
              <div class="w-16 h-16 mx-auto bg-indigo-100 rounded-lg flex items-center justify-center mb-4">
                <svg
                  class="w-8 h-8 text-indigo-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                  />
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">Library Search</h3>
              <p class="text-gray-600">Quickly find and organize your comic collection</p>
            </div>

            <div class="text-center">
              <div class="w-16 h-16 mx-auto bg-indigo-100 rounded-lg flex items-center justify-center mb-4">
                <svg
                  class="w-8 h-8 text-indigo-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">Fast & Responsive</h3>
              <p class="text-gray-600">
                Built with Phoenix LiveView for smooth, real-time interactions
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp comic_card(assigns) do
    ~H"""
    <div
      phx-click="open_comic"
      phx-value-path={@comic.path}
      class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow cursor-pointer overflow-hidden group"
    >
      <div class="aspect-[3/4] bg-gray-200 relative overflow-hidden">
        <%= if @comic.thumbnail do %>
          <img
            src={@comic.thumbnail}
            alt={@comic.title}
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
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
      </div>

      <div class="p-3">
        <h3 class="text-sm font-medium text-gray-900 truncate" title={@comic.title}>
          {@comic.title}
        </h3>
        <p class="text-xs text-gray-500 mt-1">
          {Library.format_file_size(@comic.size)}
        </p>
      </div>
    </div>
    """
  end
end
