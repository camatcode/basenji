defmodule BasenjiWeb.ComicsLive.Index do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.ComicComponents
  import BasenjiWeb.SharedComponents
  import BasenjiWeb.Style.SharedStyle

  alias Basenji.Comics

  @per_page 24
  @page_title "Comics Library"

  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, @page_title)
    |> assign_search_options()
    |> assign_page()
    |> assign_comics()
    |> then(&{:ok, &1})
  end

  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || ""
    format = params["format"] || ""
    sort = params["sort"] || "title"

    socket
    |> assign_page(page, search, format, sort)
    |> assign_comics()
    |> then(&{:noreply, &1})
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

  defp assign_search_options(socket) do
    formats = Comics.formats()
    str_formats = formats |> Enum.map(&String.upcase("#{&1}"))
    filter_options = Enum.zip(formats, str_formats)

    info = %{
      sort_options: [
        {"title", "Sort by Title"},
        {"author", "Sort by Author"},
        {"inserted_at", "Sort by Date Added"},
        {"released_year", "Sort by Release Year"}
      ],
      placeholder: "Search comics by title, author, or description...",
      filter_info: %{type: "filter_format", default: "All Formats", options: filter_options}
    }

    socket
    |> assign(:search_options_info, info)
  end

  defp assign_page(socket, current_page \\ 1, search_query \\ "", format_filter \\ "", sort_by \\ "title") do
    socket
    |> assign(:page_info, %{
      current_page: current_page,
      search_query: search_query,
      format_filter: format_filter,
      sort_by: sort_by
    })
    |> assign(:current_page, current_page)
    |> assign(:search_query, search_query)
    |> assign(:format_filter, format_filter)
    |> assign(:sort_by, sort_by)
  end

  defp assign_comics(socket) do
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

  attr :total_comics, :integer, required: true
  attr :page_info, :map, required: true
  attr :search_options_info, :map

  def render(assigns) do
    ~H"""
    <div class={page_classes(:container)}>
      <.comics_library_header total_comics={@total_comics} />

      <.search_filter_bar
        search_query={@page_info.search_query}
        search_placeholder={@search_options_info.placeholder}
        sort_options={@search_options_info.sort_options}
        }
        sort_value={@page_info.sort_by}
        filter_options={[
          {@search_options_info.filter_info.type, @search_options_info.filter_info.default,
           @search_options_info.filter_info.options, @page_info.format_filter}
        ]}
        show_clear={@page_info.search_query != "" || @page_info.format_filter != ""}
      />

      <.comics_content
        page_info={@page_info}
        comics={@comics}
        total_pages={@total_pages}
        path_function={&comics_path/1}
      />
    </div>
    """
  end

  attr :total_comics, :integer, required: true

  def comics_library_header(assigns) do
    ~H"""
    <div class={page_classes(:header_layout)}>
      <div>
        <h1 class={page_classes(:title)}>Comics Library</h1>
        <p class={page_classes(:subtitle)}>
          {@total_comics} comics total
        </p>
      </div>
    </div>
    """
  end

  attr :comics, :list, required: true
  attr :total_pages, :integer, required: true
  attr :path_function, :any, required: true
  attr :page_info, :map

  def comics_content(assigns) do
    ~H"""
    <%= if length(@comics) > 0 do %>
      <.comics_grid comics={@comics} />
      <.pagination
        current_page={@page_info.current_page}
        total_pages={@total_pages}
        path_function={@path_function}
        params={
          %{
            search: @page_info.search_query,
            format: @page_info.format_filter,
            sort: @page_info.sort_by
          }
        }
      />
    <% else %>
      <.comics_empty_state page_info={@page_info} />
    <% end %>
    """
  end

  attr :comics, :list, required: true

  def comics_grid(assigns) do
    ~H"""
    <div class={grid_classes(:comics_standard)}>
      <%= for comic <- @comics do %>
        <.comic_card comic={comic} />
      <% end %>
    </div>
    """
  end

  attr :page_info, :map

  def comics_empty_state(assigns) do
    ~H"""
    <%= if @page_info.search_query != "" or @page_info.format_filter != "" do %>
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
