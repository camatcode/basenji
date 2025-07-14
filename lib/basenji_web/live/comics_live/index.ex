defmodule BasenjiWeb.ComicsLive.Index do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.ComicComponents
  import BasenjiWeb.SharedComponents

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
      <.comics_library_header total_comics={@total_comics} />

      <.search_filter_bar
        search_query={@search_query}
        search_placeholder="Search comics by title, author, or description..."
        sort_options={[
          {"title", "Sort by Title"},
          {"author", "Sort by Author"},
          {"inserted_at", "Sort by Date Added"},
          {"released_year", "Sort by Release Year"}
        ]}
        sort_value={@sort_by}
        filter_options={[
          {"filter_format", "All Formats",
           [
             {:cbz, "CBZ"},
             {:cbt, "CBT"},
             {:cb7, "CB7"},
             {:cbr, "CBR"},
             {:pdf, "PDF"}
           ], @format_filter}
        ]}
        show_clear={@search_query != "" || @format_filter != ""}
      />

      <.comics_content
        comics={@comics}
        current_page={@current_page}
        total_pages={@total_pages}
        path_function={&comics_path/1}
        params={
          %{
            search: @search_query,
            format: @format_filter,
            sort: @sort_by
          }
        }
        search_query={@search_query}
        format_filter={@format_filter}
      />
    </div>
    """
  end

  attr :total_comics, :integer, required: true

  def comics_library_header(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
      <div>
        <h1 class="text-3xl font-bold text-gray-900">Comics Library</h1>
        <p class="text-gray-600 mt-1">
          {@total_comics} comics total
        </p>
      </div>
    </div>
    """
  end

  attr :comics, :list, required: true
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :path_function, :any, required: true
  attr :params, :map, required: true
  attr :search_query, :string, required: true
  attr :format_filter, :string, required: true

  def comics_content(assigns) do
    ~H"""
    <%= if length(@comics) > 0 do %>
      <.comics_grid comics={@comics} />
      <.pagination
        current_page={@current_page}
        total_pages={@total_pages}
        path_function={@path_function}
        params={@params}
      />
    <% else %>
      <.comics_empty_state search_query={@search_query} format_filter={@format_filter} />
    <% end %>
    """
  end

  attr :comics, :list, required: true

  def comics_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4 xl:grid-cols-5 gap-6">
      <%= for comic <- @comics do %>
        <.comic_card comic={comic} />
      <% end %>
    </div>
    """
  end

  attr :search_query, :string, required: true
  attr :format_filter, :string, required: true

  def comics_empty_state(assigns) do
    ~H"""
    <%= if @search_query != "" or @format_filter != "" do %>
      <.empty_state
        icon="hero-book-open"
        title="No comics found"
        description="Try adjusting your search terms or filters."
        show_action={true}
        action_text="Clear filters"
        action_event="clear_filters"
      />
    <% else %>
      <.empty_state
        icon="hero-book-open"
        title="No comics yet"
        description="Start building your library by adding some comic books."
      />
    <% end %>
    """
  end
end
