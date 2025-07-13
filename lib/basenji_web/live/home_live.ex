defmodule BasenjiWeb.HomeLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  alias Basenji.Collections
  alias Basenji.Comics

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:search_active, false)
      |> load_content()

    {:ok, socket}
  end

  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      if String.trim(query) == "" do
        socket
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> assign(:search_active, false)
      else
        comics = Comics.list_comics(search: query, limit: 20)
        collections = Collections.list_collections(search: query, limit: 10)

        socket
        |> assign(:search_query, query)
        |> assign(:search_results, %{comics: comics, collections: collections})
        |> assign(:search_active, true)
      end

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:search_active, false)

    {:noreply, socket}
  end

  defp load_content(socket) do
    recent_comics = Comics.list_comics(limit: 12, order_by: :inserted_at)
    recent_collections = Collections.list_collections(limit: 8, order_by: :inserted_at)

    total_comics = Comics.list_comics() |> length()
    total_collections = Collections.list_collections() |> length()

    socket
    |> assign(:recent_comics, recent_comics)
    |> assign(:recent_collections, recent_collections)
    |> assign(:total_comics, total_comics)
    |> assign(:total_collections, total_collections)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <!-- Header with Search -->
      <div class="mb-8">
        <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Basenji Comics</h1>
            <p class="text-gray-600 mt-1">
              {@total_comics} comics • {@total_collections} collections
            </p>
          </div>
          
    <!-- Search Bar -->
          <div class="lg:w-96">
            <.form for={%{}} phx-submit="search" phx-change="search" class="relative">
              <input
                type="text"
                name="search[query]"
                value={@search_query}
                placeholder="Search comics and collections..."
                class="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
              </div>
              <%= if @search_query != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="absolute inset-y-0 right-0 pr-3 flex items-center"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5 text-gray-400 hover:text-gray-600" />
                </button>
              <% end %>
            </.form>
          </div>
        </div>
      </div>
      
    <!-- Search Results -->
      <%= if @search_active do %>
        <div class="mb-8">
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
            <h2 class="text-lg font-semibold text-blue-900 mb-2">
              Search Results for "{@search_query}"
            </h2>
          </div>
          
    <!-- Comics Results -->
          <%= if length(@search_results.comics) > 0 do %>
            <div class="mb-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">
                Comics ({length(@search_results.comics)})
              </h3>
              <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
                <%= for comic <- @search_results.comics do %>
                  <.comic_card comic={comic} />
                <% end %>
              </div>
            </div>
          <% end %>
          
    <!-- Collections Results -->
          <%= if length(@search_results.collections) > 0 do %>
            <div class="mb-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">
                Collections ({length(@search_results.collections)})
              </h3>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for collection <- @search_results.collections do %>
                  <.collection_card collection={collection} />
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if length(@search_results.comics) == 0 and length(@search_results.collections) == 0 do %>
            <div class="text-center text-gray-500 py-8">
              <.icon name="hero-magnifying-glass" class="h-12 w-12 mx-auto mb-4 text-gray-300" />
              <p>No results found for "{@search_query}"</p>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Recent Content when not searching -->
        
        <!-- Recent Comics -->
        <div class="mb-8">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold text-gray-900">Recent Comics</h2>
            <.link navigate="/comics" class="text-blue-600 hover:text-blue-700 font-medium">
              View all →
            </.link>
          </div>

          <%= if length(@recent_comics) > 0 do %>
            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
              <%= for comic <- @recent_comics do %>
                <.comic_card comic={comic} />
              <% end %>
            </div>
          <% else %>
            <div class="text-center text-gray-500 py-8 border-2 border-dashed border-gray-300 rounded-lg">
              <.icon name="hero-book-open" class="h-12 w-12 mx-auto mb-4 text-gray-300" />
              <p>No comics yet. Add some comics to get started!</p>
            </div>
          <% end %>
        </div>
        
    <!-- Recent Collections -->
        <div class="mb-8">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold text-gray-900">Collections</h2>
            <.link navigate="/collections" class="text-blue-600 hover:text-blue-700 font-medium">
              View all →
            </.link>
          </div>

          <%= if length(@recent_collections) > 0 do %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              <%= for collection <- @recent_collections do %>
                <.collection_card collection={collection} />
              <% end %>
            </div>
          <% else %>
            <div class="text-center text-gray-500 py-8 border-2 border-dashed border-gray-300 rounded-lg">
              <.icon name="hero-folder" class="h-12 w-12 mx-auto mb-4 text-gray-300" />
              <p>No collections yet. Create collections to organize your comics!</p>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Comic card component
  defp comic_card(assigns) do
    ~H"""
    <div class="group cursor-pointer">
      <.link navigate={"/comics/#{@comic.id}"} class="block">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
          <!-- Comic Thumbnail Placeholder -->
          <div class="aspect-[3/4] bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center">
            <%= if @comic.image_preview do %>
              <img
                src={"/api/comics/#{@comic.id}/preview"}
                alt={@comic.title}
                class="w-full h-full object-cover"
              />
            <% else %>
              <.icon name="hero-book-open" class="h-8 w-8 text-blue-400" />
            <% end %>
          </div>
          
    <!-- Comic Info -->
          <div class="p-3">
            <h3 class="font-medium text-gray-900 text-sm line-clamp-2 group-hover:text-blue-600 transition-colors">
              {@comic.title || "Untitled"}
            </h3>
            <%= if @comic.author do %>
              <p class="text-xs text-gray-500 mt-1 truncate">{@comic.author}</p>
            <% end %>
            <div class="flex items-center justify-between mt-2">
              <span class="text-xs text-gray-400 uppercase">{@comic.format}</span>
              <%= if @comic.page_count && @comic.page_count > 0 do %>
                <span class="text-xs text-gray-400">{@comic.page_count} pages</span>
              <% end %>
            </div>
          </div>
        </div>
      </.link>
    </div>
    """
  end

  # Collection card component
  defp collection_card(assigns) do
    ~H"""
    <div class="group cursor-pointer">
      <.link navigate={"/collections/#{@collection.id}"} class="block">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 hover:shadow-md transition-shadow">
          <div class="flex items-start gap-3">
            <div class="flex-shrink-0">
              <div class="w-10 h-10 bg-yellow-100 rounded-lg flex items-center justify-center">
                <.icon name="hero-folder" class="h-6 w-6 text-yellow-600" />
              </div>
            </div>
            <div class="flex-1 min-w-0">
              <h3 class="font-medium text-gray-900 group-hover:text-blue-600 transition-colors truncate">
                {@collection.title}
              </h3>
              <%= if @collection.description do %>
                <p class="text-sm text-gray-500 mt-1 line-clamp-2">
                  {@collection.description}
                </p>
              <% end %>
              <p class="text-xs text-gray-400 mt-2">
                Collection • {DateTime.to_date(@collection.inserted_at)}
              </p>
            </div>
          </div>
        </div>
      </.link>
    </div>
    """
  end
end
