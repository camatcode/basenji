defmodule BasenjiWeb.HomeLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.CollectionComponents
  import BasenjiWeb.ComicComponents
  import BasenjiWeb.Live.Style.HomeStyle
  import BasenjiWeb.SharedComponents
  import BasenjiWeb.Style.SharedStyle

  alias Basenji.Collections
  alias Basenji.Comics

  def mount(_params, _session, socket) do
    socket
    |> assign(:search_query, "")
    |> assign(:search_results, [])
    |> assign(:search_active, false)
    |> assign_stats()
    |> then(&{:ok, &1})
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

  defp assign_stats(socket) do
    recent_comics = Comics.list_comics(limit: 12, order_by: :inserted_at)
    recent_collections = Collections.list_collections(limit: 8, order_by: :inserted_at)

    total_comics = Comics.count_comics()
    total_collections = Collections.count_collections()

    socket
    |> assign(:recent, %{comics: recent_comics, collections: recent_collections})
    |> assign(:totals, %{comics: total_comics, collections: total_collections})
  end

  attr :totals, :map
  attr :recent, :map
  attr :search_query, :string, default: ""
  attr :search_active, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <.comics_header totals={@totals} search_query={@search_query} />

      <.search_results
        search_active={@search_active}
        search_query={@search_query}
        search_results={@search_results}
        recent={@recent}
      />
    </div>
    """
  end

  attr :totals, :map
  attr :search_query, :string, default: ""

  def comics_header(assigns) do
    ~H"""
    <div class="mb-8">
      <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
        <div>
          <h1 class={page_classes(:title)}>Home</h1>
          <p class="text-gray-600 mt-1">
            {@totals.comics} comics • {@totals.collections} collections
          </p>
        </div>

        <.search_bar search_query={@search_query} />
      </div>
    </div>
    """
  end

  attr :search_query, :string, default: ""

  def search_bar(assigns) do
    # TODO hook up
    ~H"""
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
    """
  end

  attr :search_active, :boolean, default: false
  attr :search_query, :string, default: ""
  attr :search_results, :map, default: %{}
  attr :recent, :map

  def search_results(assigns) do
    ~H"""
    <%= if @search_active do %>
      <div class="mb-8">
        <.search_results_header search_query={@search_query} />
        <.comics_search_results comics={@search_results[:comics] || []} />
        <.collections_search_results collections={@search_results[:collections] || []} />
        <.no_search_results_found
          search_query={@search_query}
          comics={@search_results[:comics] || []}
          collections={@search_results[:collections] || []}
        />
      </div>
    <% else %>
      <.recent_comics_section comics={@recent.comics} />
      <.recent_collections_section collections={@recent.collections} />
    <% end %>
    """
  end

  attr :search_query, :string, required: true

  def search_results_header(assigns) do
    ~H"""
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
      <h2 class="text-lg font-semibold text-blue-900 mb-2">
        Search Results for "{@search_query}"
      </h2>
    </div>
    """
  end

  attr :comics, :list, required: true

  def comics_search_results(assigns) do
    ~H"""
    <%= if length(@comics) > 0 do %>
      <div class="mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">
          Comics ({length(@comics)})
        </h3>
        <div class={grid_classes(:comics_standard)}>
          <%= for comic <- @comics do %>
            <.comic_card comic={comic} />
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  attr :collections, :list, required: true

  def collections_search_results(assigns) do
    ~H"""
    <%= if length(@collections) > 0 do %>
      <div class="mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">
          Collections ({length(@collections)})
        </h3>
        <div class={grid_classes(:collections_standard)}>
          <%= for collection <- @collections do %>
            <.collection_card collection={collection} />
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  attr :search_query, :string, required: true
  attr :comics, :list, required: true
  attr :collections, :list, required: true

  def no_search_results_found(assigns) do
    ~H"""
    <%= if length(@comics) == 0 and length(@collections) == 0 do %>
      <div class="text-center text-gray-500 py-8">
        <.icon name="hero-magnifying-glass" class="h-12 w-12 mx-auto mb-4 text-gray-300" />
        <p>No results found for "{@search_query}"</p>
      </div>
    <% end %>
    """
  end

  attr :comics, :list, required: true

  def recent_comics_section(assigns) do
    ~H"""
    <div class={section_classes(:container)}>
      <div class={section_classes(:header)}>
        <h2 class={section_classes(:title)}>Recent Comics</h2>
        <.link navigate="/comics" class={section_classes(:view_all_link)}>
          View all →
        </.link>
      </div>

      <%= if length(@comics) > 0 do %>
        <div class={grid_classes(:comics_standard)}>
          <%= for comic <- @comics do %>
            <.comic_card comic={comic} />
          <% end %>
        </div>
      <% else %>
        <.empty_state
          icon="hero-book-open"
          title="No comics yet"
          description="Add some comics to get started!"
          style={:dashed}
          icon_size={home_live_classes(:empty_state_icon)}
          class={home_live_classes(:empty_state_override)}
        />
      <% end %>
    </div>
    """
  end

  attr :collections, :list, required: true

  def recent_collections_section(assigns) do
    ~H"""
    <div class={section_classes(:container)}>
      <div class={section_classes(:header)}>
        <h2 class={section_classes(:title)}>Collections</h2>
        <.link navigate="/collections" class={section_classes(:view_all_link)}>
          View all →
        </.link>
      </div>

      <%= if length(@collections) > 0 do %>
        <div class={grid_classes(:collections_extended)}>
          <%= for collection <- @collections do %>
            <.collection_card collection={collection} />
          <% end %>
        </div>
      <% else %>
        <.empty_state
          icon="hero-folder"
          title="No collections yet"
          description="Create collections to organize your comics!"
          style={:dashed}
          icon_size={home_live_classes(:empty_state_icon)}
          class={home_live_classes(:empty_state_override)}
        />
      <% end %>
    </div>
    """
  end
end
