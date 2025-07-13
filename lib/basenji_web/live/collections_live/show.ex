defmodule BasenjiWeb.CollectionsLive.Show do
  @moduledoc false
  use BasenjiWeb, :live_view

  alias Basenji.Collections

  @per_page 24

  def mount(%{"id" => id}, _session, socket) do
    case Collections.get_collection(id, preload: [:comics, :parent]) do
      {:ok, collection} ->
        socket =
          socket
          |> assign(:page_title, collection.title)
          |> assign(:collection, collection)
          |> assign(:current_page, 1)
          |> assign(:sort_by, "title")
          |> assign(:search_query, "")
          |> load_comics()

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Collection not found")
          |> push_navigate(to: ~p"/collections")

        {:ok, socket}
    end
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
      |> load_comics()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => search}, socket) do
    socket = push_patch(socket, to: collection_path(socket.assigns.collection.id, %{search: search, page: 1}))
    {:noreply, socket}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    socket =
      push_patch(socket,
        to:
          collection_path(socket.assigns.collection.id, %{
            search: socket.assigns.search_query,
            sort: sort,
            page: 1
          })
      )

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket = push_patch(socket, to: collection_path(socket.assigns.collection.id, %{}))
    {:noreply, socket}
  end

  def handle_event("remove_comic", %{"comic_id" => comic_id}, socket) do
    case Collections.remove_from_collection(socket.assigns.collection.id, comic_id) do
      {:ok, _} ->
        # Reload collection to get updated comics
        {:ok, updated_collection} = Collections.get_collection(socket.assigns.collection.id, preload: [:comics, :parent])

        socket =
          socket
          |> assign(:collection, updated_collection)
          |> load_comics()
          |> put_flash(:info, "Comic removed from collection")

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to remove comic")
        {:noreply, socket}
    end
  end

  defp load_comics(socket) do
    %{
      collection: collection,
      search_query: search,
      sort_by: sort,
      current_page: page
    } = socket.assigns

    # Get all comics in collection
    all_comics = collection.comics

    # Apply search filter if provided
    filtered_comics =
      if search == "" do
        all_comics
      else
        search_term = String.downcase(search)

        Enum.filter(all_comics, fn comic ->
          String.contains?(String.downcase(comic.title || ""), search_term) or
            String.contains?(String.downcase(comic.author || ""), search_term) or
            String.contains?(String.downcase(comic.description || ""), search_term)
        end)
      end

    # Apply sorting
    sorted_comics =
      case sort do
        "title" -> Enum.sort_by(filtered_comics, & &1.title)
        "author" -> Enum.sort_by(filtered_comics, & &1.author)
        "inserted_at" -> Enum.sort_by(filtered_comics, & &1.inserted_at, {:desc, DateTime})
        "released_year" -> Enum.sort_by(filtered_comics, & &1.released_year)
        _ -> filtered_comics
      end

    # Apply pagination
    total_comics = length(sorted_comics)
    total_pages = ceil(total_comics / @per_page)
    start_index = (page - 1) * @per_page
    comics = Enum.slice(sorted_comics, start_index, @per_page)

    socket
    |> assign(:comics, comics)
    |> assign(:total_comics, total_comics)
    |> assign(:total_pages, total_pages)
  end

  defp collection_path(collection_id, params) do
    query_params =
      params
      |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
      |> Map.new()

    if Enum.empty?(query_params) do
      ~p"/collections/#{collection_id}"
    else
      ~p"/collections/#{collection_id}?#{query_params}"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Back Button -->
      <div>
        <.link
          navigate={~p"/collections"}
          class="inline-flex items-center text-gray-600 hover:text-gray-900"
        >
          <.icon name="hero-arrow-left" class="h-5 w-5 mr-2" /> Back to Collections
        </.link>
      </div>
      
    <!-- Collection Header -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div class="flex items-start gap-4">
          <div class="w-16 h-16 bg-yellow-100 rounded-lg flex items-center justify-center flex-shrink-0">
            <.icon name="hero-folder" class="h-10 w-10 text-yellow-600" />
          </div>
          <div class="flex-1">
            <h1 class="text-3xl font-bold text-gray-900 mb-2">
              {@collection.title}
            </h1>
            <%= if @collection.description do %>
              <p class="text-gray-600 mb-4 leading-relaxed">
                {@collection.description}
              </p>
            <% end %>
            <div class="flex items-center gap-4 text-sm text-gray-500">
              <span>{@total_comics} comics</span>
              <span>Created {DateTime.to_date(@collection.inserted_at)}</span>
              <%= if @collection.parent do %>
                <span>
                  Parent:
                  <.link
                    navigate={~p"/collections/#{@collection.parent.id}"}
                    class="text-blue-600 hover:text-blue-700"
                  >
                    {@collection.parent.title}
                  </.link>
                </span>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Search and Sort Controls -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div class="flex flex-col lg:flex-row gap-4">
          <!-- Search -->
          <div class="flex-1">
            <.form for={%{}} phx-submit="search" class="relative">
              <input
                type="text"
                name="search"
                value={@search_query}
                placeholder="Search comics in this collection..."
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
              <option value="author" selected={@sort_by == "author"}>Sort by Author</option>
              <option value="inserted_at" selected={@sort_by == "inserted_at"}>
                Sort by Date Added
              </option>
              <option value="released_year" selected={@sort_by == "released_year"}>
                Sort by Release Year
              </option>
            </select>
          </div>
          
    <!-- Clear Search -->
          <%= if @search_query != "" do %>
            <button
              phx-click="clear_search"
              class="px-4 py-2 text-gray-600 hover:text-gray-800 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Clear
            </button>
          <% end %>
        </div>
      </div>
      
    <!-- Comics Grid -->
      <%= if length(@comics) > 0 do %>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8 gap-4">
          <%= for comic <- @comics do %>
            <.comic_card comic={comic} show_remove={true} />
          <% end %>
        </div>
        
    <!-- Pagination -->
        <%= if @total_pages > 1 do %>
          <div class="flex items-center justify-center gap-2">
            <%= if @current_page > 1 do %>
              <.link
                patch={
                  collection_path(@collection.id, %{
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
                    collection_path(@collection.id, %{
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
                  collection_path(@collection.id, %{
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
            <.icon name="hero-book-open" class="h-16 w-16 mx-auto mb-4 text-gray-300" />
            <%= if @search_query != "" do %>
              <h3 class="text-lg font-medium text-gray-900 mb-2">No comics found</h3>
              <p class="text-gray-500 mb-4">
                No comics in this collection match your search.
              </p>
              <button
                phx-click="clear_search"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Clear search
              </button>
            <% else %>
              <h3 class="text-lg font-medium text-gray-900 mb-2">Empty collection</h3>
              <p class="text-gray-500">
                This collection doesn't have any comics yet. Add some comics to get started!
              </p>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Comic card component with remove option
  defp comic_card(assigns) do
    ~H"""
    <div class="group cursor-pointer relative">
      <.link navigate={~p"/comics/#{@comic.id}"} class="block">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
          <!-- Comic Thumbnail -->
          <div class="aspect-[3/4] bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center">
            <%= if @comic.image_preview do %>
              <img
                src={~p"/api/comics/#{@comic.id}/preview"}
                alt={@comic.title}
                class="w-full h-full object-cover"
                loading="lazy"
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
      
    <!-- Remove Button -->
      <%= if @show_remove do %>
        <button
          phx-click="remove_comic"
          phx-value-comic_id={@comic.id}
          onclick="event.stopPropagation()"
          class="absolute top-2 right-2 w-6 h-6 bg-red-600 text-white rounded-full opacity-0 group-hover:opacity-100 hover:bg-red-700 transition-all flex items-center justify-center"
          title="Remove from collection"
        >
          <.icon name="hero-x-mark" class="h-4 w-4" />
        </button>
      <% end %>
    </div>
    """
  end

  # Pagination helper
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
