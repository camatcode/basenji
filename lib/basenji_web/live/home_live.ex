defmodule BasenjiWeb.HomeLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.CollectionComponents
  import BasenjiWeb.ComicComponents
  import BasenjiWeb.SharedComponents
  import BasenjiWeb.Style.ComicStyle
  import BasenjiWeb.Style.SharedStyle

  alias Basenji.Collections
  alias Basenji.Comics

  @per_page 24

  def mount(_params, _session, socket) do
    socket
    |> assign_current_collection(nil)
    |> assign_search_options()
    |> assign_page()
    |> assign_content()
    |> then(&{:ok, &1})
  end

  def handle_params(_params, _url, socket) do
    # We don't use URL-based navigation in the unified page
    {:noreply, socket}
  end

  def handle_event("navigate_to_collection", %{"collection_id" => collection_id}, socket) do
    socket =
      socket
      |> assign_current_collection(collection_id)
      |> assign_content()

    {:noreply, socket}
  end

  def handle_event("navigate_up", _params, socket) do
    # Get parent of current collection, or go to root if current is at root level
    parent_id =
      case socket.assigns.current_collection do
        nil -> nil
        collection -> collection.parent_id
      end

    socket =
      socket
      |> assign_current_collection(parent_id)
      |> assign_content()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => search}, socket) do
    socket =
      socket
      |> assign_page(1, search, socket.assigns.format_filter, socket.assigns.sort_by)
      |> assign_content()

    {:noreply, socket}
  end

  def handle_event("filter_format", %{"format" => format}, socket) do
    socket =
      socket
      |> assign_page(1, socket.assigns.search_query, format, socket.assigns.sort_by)
      |> assign_content()

    {:noreply, socket}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    socket =
      socket
      |> assign_page(socket.assigns.current_page, socket.assigns.search_query, socket.assigns.format_filter, sort)
      |> assign_content()

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign_page(1, "", "", "title")
      |> assign_content()

    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {page_num, _} = Integer.parse(page)

    socket =
      socket
      |> assign_page(page_num, socket.assigns.search_query, socket.assigns.format_filter, socket.assigns.sort_by)
      |> assign_content()

    {:noreply, socket}
  end

  defp assign_current_collection(socket, nil) do
    socket
    |> assign(:current_collection, nil)
    |> assign(:current_collection_id, nil)
  end

  defp assign_current_collection(socket, collection_id) when is_binary(collection_id) do
    case Collections.get_collection(collection_id) do
      {:ok, collection} ->
        socket
        |> assign(:current_collection, collection)
        |> assign(:current_collection_id, collection_id)

      {:error, :not_found} ->
        # If collection not found, go back to root
        assign_current_collection(socket, nil)
    end
  end

  defp assign_content(socket) do
    current_collection_id = socket.assigns.current_collection_id

    %{
      search_query: search,
      format_filter: format,
      sort_by: sort,
      current_page: page
    } = socket.assigns

    # Get collections in current context (not paginated, not searchable for now)
    collections =
      if current_collection_id do
        Collections.list_collections(parent_id: current_collection_id, order_by: String.to_existing_atom(sort))
      else
        Collections.list_collections(parent_id: :none, order_by: String.to_existing_atom(sort))
      end

    # Get comics with search, pagination, etc
    opts = [
      limit: @per_page,
      offset: (page - 1) * @per_page,
      order_by: String.to_existing_atom(sort)
    ]

    opts =
      opts
      |> maybe_add_search(search)
      |> maybe_add_format(format)

    comics =
      if current_collection_id do
        # For now, return empty list - we'd need to implement collection comic querying
        []
      else
        Comics.list_comics(opts)
      end

    # Calculate totals for pagination
    total_comics =
      if current_collection_id do
        # Placeholder
        0
      else
        total_opts =
          []
          |> maybe_add_search(search)
          |> maybe_add_format(format)

        Comics.list_comics(total_opts) |> length()
      end

    total_pages = ceil((length(collections) + total_comics) / @per_page)

    socket
    |> assign(:collections, collections)
    |> assign(:comics, comics)
    |> assign(:total_comics, total_comics)
    |> assign(:total_pages, total_pages)
  end

  defp assign_search_options(socket) do
    formats = Comics.formats()
    str_formats = formats |> Enum.map(&String.upcase("#{&1}"))
    filter_options = Enum.zip(formats, str_formats)

    info = %{
      sort_options: [
        {"title", "Sort by Title"},
        {"inserted_at", "Sort by Date Added"}
      ],
      placeholder: "Search comics...",
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

  defp maybe_add_search(opts, ""), do: opts
  defp maybe_add_search(opts, search), do: Keyword.put(opts, :search, search)

  defp maybe_add_format(opts, ""), do: opts
  defp maybe_add_format(opts, format), do: Keyword.put(opts, :format, String.to_existing_atom(format))

  def render(assigns) do
    ~H"""
    <div class={page_classes(:container)}>
      <.page_header
        current_collection={@current_collection}
        total_items={length(@collections) + @total_comics}
      />

      <.search_filter_bar
        search_query={@page_info.search_query}
        search_placeholder={@search_options_info.placeholder}
        sort_options={@search_options_info.sort_options}
        sort_value={@page_info.sort_by}
        filter_options={[
          {@search_options_info.filter_info.type, @search_options_info.filter_info.default,
           @search_options_info.filter_info.options, @page_info.format_filter}
        ]}
        show_clear={@page_info.search_query != "" || @page_info.format_filter != ""}
      />

      <.content_section
        collections={@collections}
        comics={@comics}
        current_collection={@current_collection}
        page_info={@page_info}
        total_pages={@total_pages}
      />
    </div>
    """
  end

  attr :current_collection, :any, default: nil
  attr :total_items, :integer, required: true

  def page_header(assigns) do
    ~H"""
    <div class={page_classes(:header_layout)}>
      <div>
        <h1 class={page_classes(:title)}>
          <%= if @current_collection do %>
            {@current_collection.title}
          <% else %>
            Library
          <% end %>
        </h1>
        <p class={page_classes(:subtitle)}>
          <%= if @current_collection do %>
            Collection • {@total_items} items
          <% else %>
            {@total_items} items total
          <% end %>
        </p>
      </div>
    </div>
    """
  end

  attr :collections, :list, required: true
  attr :comics, :list, required: true
  attr :current_collection, :any, default: nil
  attr :page_info, :map, required: true
  attr :total_pages, :integer, required: true

  def content_section(assigns) do
    ~H"""
    <%= if length(@collections) > 0 || length(@comics) > 0 do %>
      <.content_grid
        collections={@collections}
        comics={@comics}
        current_collection={@current_collection}
      />
      <.pagination_section page_info={@page_info} total_pages={@total_pages} />
    <% else %>
      <.empty_state_section page_info={@page_info} current_collection={@current_collection} />
    <% end %>
    """
  end

  attr :collections, :list, required: true
  attr :comics, :list, required: true
  attr :current_collection, :any, default: nil

  def content_grid(assigns) do
    ~H"""
    <div class={grid_classes(:collections_standard)}>
      <!-- Up navigation if not at root -->
      <%= if @current_collection do %>
        <.up_card />
      <% end %>
      
    <!-- Collections first -->
      <%= for collection <- @collections do %>
        <div phx-click="navigate_to_collection" phx-value-collection_id={collection.id}>
          <.collection_card collection={collection} />
        </div>
      <% end %>
      
    <!-- Comics second -->
      <%= for comic <- @comics do %>
        <.comic_card comic={comic} />
      <% end %>
    </div>
    """
  end

  attr :page_info, :map, required: true
  attr :total_pages, :integer, required: true

  def pagination_section(assigns) do
    ~H"""
    <%= if @total_pages > 1 do %>
      <div class="flex items-center justify-center gap-2">
        <%= if @page_info.current_page > 1 do %>
          <button
            phx-click="paginate"
            phx-value-page={@page_info.current_page - 1}
            class={pagination_button_classes(:inactive)}
          >
            Previous
          </button>
        <% end %>

        <%= for page_num <- pagination_range(@page_info.current_page, @total_pages) do %>
          <%= if page_num == :ellipsis do %>
            <span class={pagination_button_classes(:ellipsis)}>...</span>
          <% else %>
            <button
              phx-click="paginate"
              phx-value-page={page_num}
              class={
                if(page_num == @page_info.current_page,
                  do: pagination_button_classes(:active),
                  else: pagination_button_classes(:inactive)
                )
              }
            >
              {page_num}
            </button>
          <% end %>
        <% end %>

        <%= if @page_info.current_page < @total_pages do %>
          <button
            phx-click="paginate"
            phx-value-page={@page_info.current_page + 1}
            class={pagination_button_classes(:inactive)}
          >
            Next
          </button>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp pagination_range(_current_page, total_pages) when total_pages <= 7 do
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

  attr :page_info, :map, required: true
  attr :current_collection, :any, default: nil

  def empty_state_section(assigns) do
    ~H"""
    <%= if @page_info.search_query != "" or @page_info.format_filter != "" do %>
      <.empty_state
        icon="hero-magnifying-glass"
        title="No items found"
        description="Try adjusting your search terms or filters."
        show_action={true}
        action_text="Clear filters"
        action_event="clear_filters"
      />
    <% else %>
      <%= if @current_collection do %>
        <.empty_state
          icon="hero-folder"
          title="Empty collection"
          description="This collection doesn't contain any items yet."
        />
      <% else %>
        <.empty_state
          icon="hero-book-open"
          title="No items yet"
          description="Start building your library by adding some comics and collections."
        />
      <% end %>
    <% end %>
    """
  end

  def up_card(assigns) do
    ~H"""
    <div class={[comic_card_classes(:container), "cursor-pointer"]} phx-click="navigate_up">
      <div class="block">
        <div class={comic_card_classes(:inner)}>
          <div class={comic_card_classes(:cover_container)}>
            <.icon name="hero-arrow-up" class={comic_card_classes(:fallback_icon)} />
          </div>
          <div class={comic_card_classes(:content_area)}>
            <h3 class={comic_card_classes(:title)}>
              ..
            </h3>
            <div class={comic_card_classes(:metadata_row)}>
              <small class={comic_card_classes(:metadata_format)}>Up</small>
              <small class={comic_card_classes(:metadata_pages)}></small>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
