defmodule BasenjiWeb.CollectionsLive.Index do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.CollectionComponents
  import BasenjiWeb.SharedComponents

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
      <.collections_header total_collections={@total_collections} />

      <.search_filter_bar
        search_query={@search_query}
        search_placeholder="Search collections by title or description..."
        sort_options={[
          {"title", "Sort by Title"},
          {"inserted_at", "Sort by Date Created"},
          {"updated_at", "Sort by Last Updated"}
        ]}
        sort_value={@sort_by}
        show_clear={@search_query != ""}
      />

      <.collections_content
        collections={@collections}
        current_page={@current_page}
        total_pages={@total_pages}
        path_function={&collections_path/1}
        params={
          %{
            search: @search_query,
            sort: @sort_by
          }
        }
        search_query={@search_query}
      />
    </div>
    """
  end

  attr :total_collections, :integer, required: true

  def collections_header(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
      <div>
        <h1 class="text-3xl font-bold text-gray-900">Collections</h1>
        <p class="text-gray-600 mt-1">
          {@total_collections} collections total
        </p>
      </div>
    </div>
    """
  end

  attr :collections, :list, required: true
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :path_function, :any, required: true
  attr :params, :map, required: true
  attr :search_query, :string, required: true

  def collections_content(assigns) do
    ~H"""
    <%= if length(@collections) > 0 do %>
      <.collections_grid collections={@collections} />
      <.pagination
        current_page={@current_page}
        total_pages={@total_pages}
        path_function={@path_function}
        params={@params}
      />
    <% else %>
      <.collections_empty_state search_query={@search_query} />
    <% end %>
    """
  end

  attr :collections, :list, required: true

  def collections_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
      <%= for collection <- @collections do %>
        <.collection_card collection={collection} show_comic_count={true} />
      <% end %>
    </div>
    """
  end

  attr :search_query, :string, required: true

  def collections_empty_state(assigns) do
    ~H"""
    <%= if @search_query != "" do %>
      <.empty_state
        icon="hero-folder"
        title="No collections found"
        description="Try adjusting your search terms."
        show_action={true}
        action_text="Clear search"
        action_event="clear_filters"
      />
    <% else %>
      <.empty_state
        icon="hero-folder"
        title="No collections yet"
        description="Create collections to organize your comics by series, genre, or any way you like."
      />
    <% end %>
    """
  end
end
