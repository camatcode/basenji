defmodule BasenjiWeb.CollectionsLive.Index do
  @moduledoc false
  use BasenjiWeb, :live_view

  alias Basenji.Collections

  @per_page 20

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Collections")
      |> assign(:search_query, "")
      |> assign(:current_page, 1)
      |> assign(:sort_by, "title")
      |> load_collections()

    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || ""
    sort = params["sort"] || "title"

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:search_query, search)
      |> assign(:sort_by, sort)
      |> load_collections()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => search}, socket) do
    socket = push_patch(socket, to: collections_path(%{search: search, page: 1}))
    {:noreply, socket}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    socket =
      push_patch(socket,
        to:
          collections_path(%{
            search: socket.assigns.search_query,
            sort: sort,
            page: 1
          })
      )

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    socket = push_patch(socket, to: collections_path(%{}))
    {:noreply, socket}
  end

  defp load_collections(socket) do
    %{
      search_query: search,
      sort_by: sort,
      current_page: page
    } = socket.assigns

    opts = [
      limit: @per_page,
      offset: (page - 1) * @per_page,
      order_by: String.to_existing_atom(sort),
      preload: [:comics]
    ]

    opts = maybe_add_search(opts, search)

    collections = Collections.list_collections(opts)
    total_collections = Collections.list_collections(maybe_add_search([], search)) |> length()
    total_pages = ceil(total_collections / @per_page)

    socket
    |> assign(:collections, collections)
    |> assign(:total_collections, total_collections)
    |> assign(:total_pages, total_pages)
  end

  defp maybe_add_search(opts, ""), do: opts
  defp maybe_add_search(opts, search), do: Keyword.put(opts, :search, search)

  defp collections_path(params) do
    query_params =
      params
      |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
      |> Map.new()

    if Enum.empty?(query_params) do
      ~p"/collections"
    else
      ~p"/collections?#{query_params}"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Collections</h1>
          <p class="text-gray-600 mt-1">
            {@total_collections} collections total
          </p>
        </div>
      </div>
      
    <!-- Search and Filters -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div class="flex flex-col lg:flex-row gap-4">
          <!-- Search -->
          <div class="flex-1">
            <.form for={%{}} phx-submit="search" class="relative">
              <input
                type="text"
                name="search"
                value={@search_query}
                placeholder="Search collections by title or description..."
                class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
              </div>
            </.form>
          </div>
          
    <!-- Sort -->
          <div class="lg:w-48">
            <select
              phx-change="sort"
              name="sort"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="title" selected={@sort_by == "title"}>Sort by Title</option>
              <option value="inserted_at" selected={@sort_by == "inserted_at"}>
                Sort by Date Created
              </option>
              <option value="updated_at" selected={@sort_by == "updated_at"}>
                Sort by Last Updated
              </option>
            </select>
          </div>
          
    <!-- Clear Filters -->
          <%= if @search_query != "" do %>
            <button
              phx-click="clear_filters"
              class="px-4 py-2 text-gray-600 hover:text-gray-800 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Clear
            </button>
          <% end %>
        </div>
      </div>
      
    <!-- Collections Grid -->
      <%= if length(@collections) > 0 do %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          <%= for collection <- @collections do %>
            <.collection_card collection={collection} />
          <% end %>
        </div>
        
    <!-- Pagination -->
        <%= if @total_pages > 1 do %>
          <div class="flex items-center justify-center gap-2">
            <%= if @current_page > 1 do %>
              <.link
                patch={
                  collections_path(%{
                    search: @search_query,
                    sort: @sort_by,
                    page: @current_page - 1
                  })
                }
                class="px-3 py-2 text-gray-500 hover:text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Previous
              </.link>
            <% end %>

            <%= for page_num <- pagination_range(@current_page, @total_pages) do %>
              <%= if page_num == :ellipsis do %>
                <span class="px-3 py-2 text-gray-400">...</span>
              <% else %>
                <.link
                  patch={
                    collections_path(%{
                      search: @search_query,
                      sort: @sort_by,
                      page: page_num
                    })
                  }
                  class={[
                    "px-3 py-2 border rounded-md",
                    if(page_num == @current_page,
                      do: "bg-blue-600 text-white border-blue-600",
                      else: "text-gray-500 hover:text-gray-700 border-gray-300 hover:bg-gray-50"
                    )
                  ]}
                >
                  {page_num}
                </.link>
              <% end %>
            <% end %>

            <%= if @current_page < @total_pages do %>
              <.link
                patch={
                  collections_path(%{
                    search: @search_query,
                    sort: @sort_by,
                    page: @current_page + 1
                  })
                }
                class="px-3 py-2 text-gray-500 hover:text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Next
              </.link>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <!-- Empty State -->
        <div class="text-center py-12">
          <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
            <.icon name="hero-folder" class="h-16 w-16 mx-auto mb-4 text-gray-300" />
            <%= if @search_query != "" do %>
              <h3 class="text-lg font-medium text-gray-900 mb-2">No collections found</h3>
              <p class="text-gray-500 mb-4">
                Try adjusting your search terms.
              </p>
              <button
                phx-click="clear_filters"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Clear search
              </button>
            <% else %>
              <h3 class="text-lg font-medium text-gray-900 mb-2">No collections yet</h3>
              <p class="text-gray-500">
                Create collections to organize your comics by series, genre, or any way you like.
              </p>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Collection card component
  defp collection_card(assigns) do
    ~H"""
    <div class="group cursor-pointer">
      <.link navigate={~p"/collections/#{@collection.id}"} class="block">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow h-full">
          <div class="flex items-start gap-4">
            <div class="flex-shrink-0">
              <div class="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
                <.icon name="hero-folder" class="h-7 w-7 text-yellow-600" />
              </div>
            </div>
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold text-gray-900 group-hover:text-blue-600 transition-colors mb-2">
                {@collection.title}
              </h3>
              <%= if @collection.description do %>
                <p class="text-sm text-gray-600 mb-3 line-clamp-3">
                  {@collection.description}
                </p>
              <% end %>

              <div class="flex items-center justify-between text-xs text-gray-500">
                <span>{length(@collection.comics)} comics</span>
                <span>{DateTime.to_date(@collection.inserted_at)}</span>
              </div>
            </div>
          </div>
        </div>
      </.link>
    </div>
    """
  end

  # Pagination helper (same as comics)
  defp pagination_range(current_page, total_pages) when total_pages <= 7 do
    1..total_pages |> Enum.to_list()
  end

  defp pagination_range(current_page, total_pages) do
    cond do
      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis, total_pages - 4, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

      true ->
        [1, :ellipsis, current_page - 1, current_page, current_page + 1, :ellipsis, total_pages]
    end
  end
end
