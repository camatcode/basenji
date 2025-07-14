defmodule BasenjiWeb.ComicsLive.Index do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.ComicComponents

  alias Basenji.Comics

  @per_page 24

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Comics Library")
      |> assign(:search_query, "")
      |> assign(:current_page, 1)
      |> assign(:format_filter, "")
      |> assign(:sort_by, "title")
      |> load_comics()

    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || ""
    format = params["format"] || ""
    sort = params["sort"] || "title"

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:search_query, search)
      |> assign(:format_filter, format)
      |> assign(:sort_by, sort)
      |> load_comics()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => search}, socket) do
    socket = push_patch(socket, to: comics_path(%{search: search, page: 1}))
    {:noreply, socket}
  end

  def handle_event("filter_format", %{"format" => format}, socket) do
    socket =
      push_patch(socket,
        to:
          comics_path(%{
            search: socket.assigns.search_query,
            format: format,
            sort: socket.assigns.sort_by,
            page: 1
          })
      )

    {:noreply, socket}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    socket =
      push_patch(socket,
        to:
          comics_path(%{
            search: socket.assigns.search_query,
            format: socket.assigns.format_filter,
            sort: sort,
            page: 1
          })
      )

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    socket = push_patch(socket, to: comics_path(%{}))
    {:noreply, socket}
  end

  defp load_comics(socket) do
    %{
      search_query: search,
      format_filter: format,
      sort_by: sort,
      current_page: page
    } = socket.assigns

    opts = [
      limit: @per_page,
      offset: (page - 1) * @per_page,
      order_by: String.to_existing_atom(sort)
    ]

    opts =
      opts
      |> maybe_add_search(search)
      |> maybe_add_format(format)

    comics = Comics.list_comics(opts)
    total_comics = Comics.list_comics(maybe_add_search([], search) |> maybe_add_format(format)) |> length()
    total_pages = ceil(total_comics / @per_page)

    socket
    |> assign(:comics, comics)
    |> assign(:total_comics, total_comics)
    |> assign(:total_pages, total_pages)
  end

  defp maybe_add_search(opts, ""), do: opts
  defp maybe_add_search(opts, search), do: Keyword.put(opts, :search, search)

  defp maybe_add_format(opts, ""), do: opts
  defp maybe_add_format(opts, format), do: Keyword.put(opts, :format, String.to_existing_atom(format))

  defp comics_path(params) do
    query_params =
      params
      |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
      |> Map.new()

    if Enum.empty?(query_params) do
      ~p"/comics"
    else
      ~p"/comics?#{query_params}"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Comics Library</h1>
          <p class="text-gray-600 mt-1">
            {@total_comics} comics total
          </p>
        </div>
      </div>
      
    <!-- Search and Filters -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div class="flex flex-col lg:flex-row gap-6">
          <!-- Search -->
          <div class="flex-1">
            <.form for={%{}} phx-submit="search" class="relative">
              <input
                type="text"
                name="search"
                value={@search_query}
                placeholder="Search comics by title, author, or description..."
                class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
              </div>
            </.form>
          </div>
          
    <!-- Format Filter -->
          <div class="lg:w-48">
            <select
              phx-change="filter_format"
              name="format"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">All Formats</option>
              <%= for format <- [:cbz, :cbt, :cb7, :cbr, :pdf] do %>
                <option value={format} selected={@format_filter == Atom.to_string(format)}>
                  {String.upcase(Atom.to_string(format))}
                </option>
              <% end %>
            </select>
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
          
    <!-- Clear Filters -->
          <%= if @search_query != "" or @format_filter != "" do %>
            <button
              phx-click="clear_filters"
              class="px-4 py-2 text-gray-600 hover:text-gray-800 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Clear
            </button>
          <% end %>
        </div>
      </div>
      
    <!-- Comics Grid -->
      <%= if length(@comics) > 0 do %>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4 xl:grid-cols-5 gap-6">
          <%= for comic <- @comics do %>
            <.comic_card comic={comic} />
          <% end %>
        </div>
        
    <!-- Pagination -->
        <%= if @total_pages > 1 do %>
          <div class="flex items-center justify-center gap-2">
            <%= if @current_page > 1 do %>
              <.link
                patch={
                  comics_path(%{
                    search: @search_query,
                    format: @format_filter,
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
                    comics_path(%{
                      search: @search_query,
                      format: @format_filter,
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
                  comics_path(%{
                    search: @search_query,
                    format: @format_filter,
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
            <%= if @search_query != "" or @format_filter != "" do %>
              <h3 class="text-lg font-medium text-gray-900 mb-2">No comics found</h3>
              <p class="text-gray-500 mb-4">
                Try adjusting your search terms or filters.
              </p>
              <button
                phx-click="clear_filters"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Clear filters
              </button>
            <% else %>
              <h3 class="text-lg font-medium text-gray-900 mb-2">No comics yet</h3>
              <p class="text-gray-500">
                Start building your library by adding some comic books.
              </p>
            <% end %>
          </div>
        </div>
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
