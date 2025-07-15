defmodule BasenjiWeb.HomeLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.CollectionComponents
  import BasenjiWeb.ComicComponents
  import BasenjiWeb.SharedComponents
  import BasenjiWeb.Style.ComicStyle
  import BasenjiWeb.Style.SharedStyle

  alias Basenji.Comics
  alias Phoenix.HTML.Form

  @per_page 24

  def mount(_params, _session, socket) do
    # Initialize form changeset
    form_params = %{
      "search_query" => "",
      "format_filter" => "",
      "sort_by" => "title"
    }

    form = to_form(form_params, as: :search_form)

    socket
    |> assign_search_options()
    |> assign(:search_form, form)
    |> assign_page()
    |> assign_content()
    |> then(&{:ok, &1})
  end

  # Handle unified form submission
  def handle_event("search_submit", %{"search_form" => form_params}, socket) do
    search = Map.get(form_params, "search_query", "")
    format = Map.get(form_params, "format_filter", "")
    sort = Map.get(form_params, "sort_by", "title")

    # Update form state
    form = to_form(form_params, as: :search_form)

    socket
    |> assign(:search_form, form)
    |> assign_page(1, search, format, sort)
    |> assign_content()
    |> then(&{:noreply, &1})
  end

  # Handle individual field changes (for immediate feedback)
  def handle_event("search_change", %{"search_form" => form_params}, socket) do
    # Update form state without triggering search
    form = to_form(form_params, as: :search_form)

    socket
    |> assign(:search_form, form)
    |> then(&{:noreply, &1})
  end

  # Handle quick filter changes (immediate effect)  
  def handle_event("quick_filter", %{"search_form" => %{"format_filter" => format}}, socket) do
    search = socket.assigns.search_form.params["search_query"] || ""
    sort = socket.assigns.search_form.params["sort_by"] || "title"

    new_params = %{
      "search_query" => search,
      "format_filter" => format,
      "sort_by" => sort
    }

    form = to_form(new_params, as: :search_form)

    socket
    |> assign(:search_form, form)
    |> assign_page(1, search, format, sort)
    |> assign_content()
    |> then(&{:noreply, &1})
  end

  def handle_event("quick_filter", %{"search_form" => %{"sort_by" => sort}}, socket) do
    search = socket.assigns.search_form.params["search_query"] || ""
    format = socket.assigns.search_form.params["format_filter"] || ""

    new_params = %{
      "search_query" => search,
      "format_filter" => format,
      "sort_by" => sort
    }

    form = to_form(new_params, as: :search_form)

    socket
    |> assign(:search_form, form)
    |> assign_page(1, search, format, sort)
    |> assign_content()
    |> then(&{:noreply, &1})
  end

  def handle_event("clear_filters", _params, socket) do
    # Reset form to defaults
    form_params = %{
      "search_query" => "",
      "format_filter" => "",
      "sort_by" => "title"
    }

    form = to_form(form_params, as: :search_form)

    socket
    |> assign(:search_form, form)
    |> assign_page()
    |> assign_content()
    |> then(&{:noreply, &1})
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {page_num, _} = Integer.parse(page)

    # Keep current form state, just change page
    form_params = socket.assigns.search_form.params
    search = Map.get(form_params, "search_query", "")
    format = Map.get(form_params, "format_filter", "")
    sort = Map.get(form_params, "sort_by", "title")

    socket
    |> assign_page(page_num, search, format, sort)
    |> assign_content()
    |> then(&{:noreply, &1})
  end

  defp assign_content(socket) do
    %{
      search_query: search,
      format_filter: format,
      sort_by: sort,
      current_page: page
    } = socket.assigns

    # Get comics with search, pagination, etc
    opts = [
      limit: @per_page,
      offset: (page - 1) * @per_page,
      order_by: safe_sort_atom(sort)
    ]

    opts =
      opts
      |> maybe_add_search(search)
      |> maybe_add_format(format)

    comics = Comics.list_comics(opts)

    total_opts =
      []
      |> maybe_add_search(search)
      |> maybe_add_format(format)

    total_comics = Comics.list_comics(total_opts) |> length()
    total_pages = ceil(total_comics / @per_page)

    socket
    |> assign(:comics, comics)
    |> assign(:total_comics, total_comics)
    |> assign(:total_pages, total_pages)
  end

  defp assign_search_options(socket) do
    formats = Comics.formats()
    # Create options with string values and uppercase labels
    filter_options =
      formats
      |> Enum.map(fn format ->
        {Atom.to_string(format), String.upcase("#{format}")}
      end)

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

  defp maybe_add_format(opts, format) when is_binary(format) do
    # Convert to lowercase and then to atom safely
    format_atom =
      format
      |> String.downcase()
      |> String.to_atom()

    Keyword.put(opts, :format, format_atom)
  end

  # Safely convert sort values to atoms
  defp safe_sort_atom(sort) when is_binary(sort) do
    case sort do
      "title" -> :title
      "inserted_at" -> :inserted_at
      # Handle incorrect form submission
      "Sort by Title" -> :title
      # Handle incorrect form submission
      "Sort by Date Added" -> :inserted_at
      # Default fallback
      _ -> :title
    end
  end

  defp safe_sort_atom(sort) when is_atom(sort), do: sort

  def render(assigns) do
    ~H"""
    <div class={page_classes(:container)} id="page-container">
      <.unified_search_bar
        form={@search_form}
        search_options={@search_options_info}
        page_info={@page_info}
      />

      <.pagination_section page_info={@page_info} total_pages={@total_pages} />

      <.content_section comics={@comics} page_info={@page_info} />

      <.pagination_section page_info={@page_info} total_pages={@total_pages} />
    </div>
    """
  end

  attr :form, Form, required: true
  attr :search_options, :map, required: true
  attr :page_info, :map, required: true

  def unified_search_bar(assigns) do
    ~H"""
    <div class={container_classes(:search_bar)}>
      <.form
        for={@form}
        phx-submit="search_submit"
        phx-change="search_change"
        class="flex flex-col lg:flex-row gap-6"
      >
        <!-- Search Input -->
        <div class="flex-1">
          <div class="relative">
            <.input
              field={@form[:search_query]}
              type="text"
              placeholder={@search_options.placeholder}
              class={[search_input_classes(), "pl-10"]}
            />
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
            </div>
          </div>
        </div>
        
    <!-- Format Filter -->
        <div class="lg:w-48">
          <select
            name="search_form[format_filter]"
            value={@form[:format_filter].value || ""}
            class={form_input_classes()}
          >
            <option value="">All Formats</option>
            <%= for {value, label} <- @search_options.filter_info.options do %>
              <option value={value} selected={@form[:format_filter].value == value}>
                {label}
              </option>
            <% end %>
          </select>
        </div>
        
    <!-- Sort -->
        <div class="lg:w-48">
          <select
            name="search_form[sort_by]"
            value={@form[:sort_by].value || "title"}
            class={form_input_classes()}
          >
            <%= for {value, label} <- @search_options.sort_options do %>
              <option value={value} selected={@form[:sort_by].value == value}>
                {label}
              </option>
            <% end %>
          </select>
        </div>
        
    <!-- Submit & Clear -->
        <div class="flex gap-2">
          <button type="submit" class={button_classes(:primary)}>
            Search
          </button>
          <%= if @page_info.search_query != "" || @page_info.format_filter != "" do %>
            <button type="button" phx-click="clear_filters" class={button_classes(:secondary)}>
              Clear
            </button>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end

  attr :total_items, :integer, required: true

  def page_header(assigns) do
    ~H"""
    <div class={page_classes(:header_layout)}>
      <div>
        <h1 class={page_classes(:title)}>
          Library
        </h1>
        <p class={page_classes(:subtitle)}>
          {@total_items} comics total
        </p>
      </div>
    </div>
    """
  end

  attr :comics, :list, required: true
  attr :page_info, :map, required: true

  def content_section(assigns) do
    ~H"""
    <%= if length(@comics) > 0 do %>
      <.content_grid comics={@comics} />
    <% else %>
      <.empty_state_section page_info={@page_info} />
    <% end %>
    """
  end

  attr :comics, :list, required: true

  def content_grid(assigns) do
    ~H"""
    <div class={grid_classes(:comics_standard)}>
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
            onclick="window.scrollTo(0,0)"
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
              onclick="window.scrollTo(0,0)"
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
            onclick="window.scrollTo(0,0)"
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

  def empty_state_section(assigns) do
    ~H"""
    <%= if @page_info.search_query != "" or @page_info.format_filter != "" do %>
      <.empty_state
        icon="hero-magnifying-glass"
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
        description="Start building your library by adding some comics."
      />
    <% end %>
    """
  end
end
