defmodule BasenjiWeb.HomeLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.SharedComponents
  import BasenjiWeb.Style.SharedStyle

  alias Basenji.Comics
  alias Phoenix.HTML.Form

  @per_page 24

  def mount(_params, _session, socket) do
    socket
    |> assign_search_options()
    |> assign_content()
    |> then(&{:ok, &1})
  end

  def handle_event("search", %{"search_form" => form_params}, socket) do
    search = Map.get(form_params, "search_query", "")
    format = Map.get(form_params, "format_filter", "")
    sort = Map.get(form_params, "sort_by", "title")

    socket
    |> assign_content(1, search, format, sort)
    |> then(&{:noreply, &1})
  end

  def handle_event("clear_filters", _params, socket) do
    socket
    |> assign_content()
    |> then(&{:noreply, &1})
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {page_num, _} = Integer.parse(page)

    form_params = socket.assigns.search_form.params
    search = Map.get(form_params, "search_query", "")
    format = Map.get(form_params, "format_filter", "")
    sort = Map.get(form_params, "sort_by", "title")

    socket
    |> assign_content(page_num, search, format, sort)
    |> then(&{:noreply, &1})
  end

  defp assign_content(socket, current_page \\ 1, search_query \\ "", format_filter \\ "", sort_by \\ "title") do
    socket = assign_page(socket, current_page, search_query, format_filter, sort_by)

    %{
      search_query: search,
      format_filter: format,
      sort_by: sort,
      current_page: page
    } = socket.assigns

    opts =
      [
        limit: @per_page,
        offset: (page - 1) * @per_page,
        order_by: safe_sort_atom(sort)
      ]
      |> maybe_add_search(search)
      |> maybe_add_format(format)

    results = Comics.list_comics(opts)

    total_opts =
      []
      |> maybe_add_search(search)
      |> maybe_add_format(format)

    total_comics = Comics.count_comics(total_opts)
    total_pages = ceil(total_comics / @per_page)

    socket
    |> assign(:comics, results)
    |> assign(:total_pages, total_pages)
  end

  defp assign_search_options(socket) do
    filter_options =
      Comics.formats()
      |> Enum.map(fn format ->
        {Atom.to_string(format), String.upcase("#{format}")}
      end)

    info = %{
      sort_options: [
        {"title", "Sort by Title"},
        {"inserted_at", "Sort by Date Added"}
      ],
      placeholder: "Search comics...",
      filter_info: %{type: "filter_format", default: "All Formats", options: [{"", "All Formats"}] ++ filter_options}
    }

    socket
    |> assign(:search_options_info, info)
  end

  defp assign_page(socket, current_page, search_query, format_filter, sort_by) do
    form_params = %{
      "search_query" => search_query,
      "format_filter" => format_filter,
      "sort_by" => sort_by
    }

    page_info = %{
      current_page: current_page,
      search_query: search_query,
      format_filter: format_filter,
      sort_by: sort_by
    }

    socket
    |> assign(:page_info, page_info)
    |> assign(:current_page, current_page)
    |> assign(:search_query, search_query)
    |> assign(:format_filter, format_filter)
    |> assign(:sort_by, sort_by)
    |> assign(:search_form, to_form(form_params, as: :search_form))
  end

  defp maybe_add_search(opts, ""), do: opts
  defp maybe_add_search(opts, search), do: Keyword.put(opts, :search, search)

  defp maybe_add_format(opts, ""), do: opts

  defp maybe_add_format(opts, format) when is_binary(format) do
    format_atom =
      format
      |> String.downcase()
      |> String.to_atom()

    Keyword.put(opts, :format, format_atom)
  end

  defp safe_sort_atom(sort) when is_binary(sort) do
    case sort do
      "inserted_at" -> :inserted_at
      "Sort by Date Added" -> :inserted_at
      _ -> :title
    end
  end

  defp safe_sort_atom(sort) when is_atom(sort), do: sort

  def render(assigns) do
    ~H"""
    <div class={page_classes(:container)} id="page-container">
      <.search_bar form={@search_form} search_options={@search_options_info} page_info={@page_info} />

      <.pagination_section id="top_pagination" page_info={@page_info} total_pages={@total_pages} />

      <.content_section comics={@comics} page_info={@page_info} />

      <.pagination_section id="bottom_pagination" page_info={@page_info} total_pages={@total_pages} />
    </div>
    """
  end

  attr :form, Form, required: true
  attr :search_options, :map, required: true
  attr :page_info, :map, required: true

  def search_bar(assigns) do
    ~H"""
    <div class={container_classes(:search_bar)}>
      <.form
        for={@form}
        phx-submit="search"
        phx-change="search"
        class="flex flex-col lg:flex-row gap-2 lg:items-center"
      >
        <div class="flex-1">
          <.input
            field={@form[:search_query]}
            type="text"
            placeholder={@search_options.placeholder}
            class={[search_input_classes()]}
          />
        </div>

        <div class="lg:w-48 lg:pt-2">
          <select
            name="search_form[format_filter]"
            value={@form[:format_filter].value || ""}
            class={[form_input_classes()]}
          >
            <option value="" selected={@form[:format_filter].value == ""} label="All Formats" />
            <%= for {value, label} <- @search_options.filter_info.options do %>
              <option value={value} selected={@form[:format_filter].value == value} label={label} />
            <% end %>
          </select>
        </div>

        <div class="lg:w-48 lg:pt-2">
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

        <%= if @page_info.search_query != "" || @page_info.format_filter != "" do %>
          <button type="button" phx-click="clear_filters" class={button_classes(:secondary)}>
            Reset
          </button>
        <% end %>
      </.form>
    </div>
    """
  end

  attr :comics, :list, required: true
  attr :page_info, :map, required: true

  def content_section(assigns) do
    ~H"""
    <%= if Enum.empty?(@comics) do %>
      <.empty_state_section page_info={@page_info} />
    <% else %>
      <div class={grid_classes(:comics_standard)}>
        <%= for comic <- @comics do %>
          <.live_component
            id={"comic_card_#{comic.id}"}
            module={BasenjiWeb.ComicCardComponent}
            comic={comic}
          />
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :page_info, :map, required: true
  attr :total_pages, :integer, required: true
  attr :id, :string, required: true

  def pagination_section(assigns) do
    ~H"""
    <%= if @total_pages > 1 do %>
      <div id={@id} class="flex items-center justify-center gap-2">
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
