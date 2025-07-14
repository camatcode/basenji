defmodule BasenjiWeb.SharedComponents do
  @moduledoc false
  use BasenjiWeb, :live_component

  import BasenjiWeb.CoreComponents

  attr :current_page, :integer, required: true, doc: "Current page number"
  attr :total_pages, :integer, required: true, doc: "Total number of pages"
  attr :path_function, :any, required: true, doc: "Function that generates path URLs for pagination"
  attr :params, :map, default: %{}, doc: "Current search/filter parameters to preserve"

  def pagination(assigns) do
    ~H"""
    <%= if @total_pages > 1 do %>
      <div class="flex items-center justify-center gap-2">
        <%= if @current_page > 1 do %>
          <.link
            patch={@path_function.(Map.put(@params, :page, @current_page - 1))}
            class={pagination_button_classes(:inactive)}
          >
            Previous
          </.link>
        <% end %>

        <%= for page_num <- pagination_range(@current_page, @total_pages) do %>
          <%= if page_num == :ellipsis do %>
            <span class={pagination_button_classes(:ellipsis)}>...</span>
          <% else %>
            <.link
              patch={@path_function.(Map.put(@params, :page, page_num))}
              class={
                if(page_num == @current_page,
                  do: pagination_button_classes(:active),
                  else: pagination_button_classes(:inactive)
                )
              }
            >
              {page_num}
            </.link>
          <% end %>
        <% end %>

        <%= if @current_page < @total_pages do %>
          <.link
            patch={@path_function.(Map.put(@params, :page, @current_page + 1))}
            class={pagination_button_classes(:inactive)}
          >
            Next
          </.link>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :search_query, :string, required: true, doc: "Current search query value"
  attr :search_placeholder, :string, default: "Search...", doc: "Placeholder text for search input"
  attr :sort_options, :list, default: [], doc: "List of sort options [{value, label}]"
  attr :sort_value, :string, default: "", doc: "Current sort value"
  attr :filter_options, :list, default: [], doc: "List of filter sections [{type, label, options, current_value}]"
  attr :show_clear, :boolean, default: false, doc: "Whether to show clear filters button"
  attr :clear_event, :string, default: "clear_filters", doc: "Phoenix event to trigger when clear button is clicked"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def search_filter_bar(assigns) do
    ~H"""
    <div class={["bg-white rounded-lg shadow-sm border border-gray-200 p-6", @class]}>
      <div class="flex flex-col lg:flex-row gap-6">
        <!-- Search -->
        <div class="flex-1">
          <.form for={%{}} phx-submit="search" class="relative">
            <input
              type="text"
              name="search"
              value={@search_query}
              placeholder={@search_placeholder}
              class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
            </div>
          </.form>
        </div>
        
    <!-- Custom Filters -->
        <%= for {filter_type, filter_label, filter_options, current_value} <- @filter_options do %>
          <div class="lg:w-48">
            <select
              phx-change={filter_type}
              name={filter_type}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">{filter_label}</option>
              <%= for {value, label} <- filter_options do %>
                <option
                  value={value}
                  selected={current_value == Atom.to_string(value) || current_value == value}
                >
                  {label}
                </option>
              <% end %>
            </select>
          </div>
        <% end %>
        
    <!-- Sort -->
        <%= if length(@sort_options) > 0 do %>
          <div class="lg:w-48">
            <select
              phx-change="sort"
              name="sort"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <%= for {value, label} <- @sort_options do %>
                <option value={value} selected={@sort_value == value}>
                  {label}
                </option>
              <% end %>
            </select>
          </div>
        <% end %>
        
    <!-- Clear Filters -->
        <%= if @show_clear do %>
          <button
            phx-click={@clear_event}
            class="px-4 py-2 text-gray-600 hover:text-gray-800 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Clear
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true, doc: "Heroicon name for the empty state"
  attr :title, :string, required: true, doc: "Title text for the empty state"
  attr :description, :string, required: true, doc: "Description text for the empty state"
  attr :show_action, :boolean, default: false, doc: "Whether to show an action button"
  attr :action_text, :string, default: "Take Action", doc: "Text for the action button"
  attr :action_event, :string, default: "", doc: "Phoenix event to trigger when action button is clicked"
  attr :style, :atom, default: :card, doc: "Style variant: :card (default) or :dashed"
  attr :icon_size, :string, default: "h-16 w-16", doc: "Tailwind classes for icon size"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def empty_state(assigns) do
    ~H"""
    <div class={["text-center py-12", @class]}>
      <div class={[
        "p-8",
        if(@style == :dashed,
          do: "border-2 border-dashed border-gray-300 rounded-lg",
          else: "bg-white rounded-lg shadow-sm border border-gray-200"
        )
      ]}>
        <.icon name={@icon} class={String.trim("#{@icon_size} mx-auto mb-4 text-gray-300")} />
        <h3 class="text-lg font-medium text-gray-900 mb-2">{@title}</h3>
        <%= if @description != "" do %>
          <p class={[
            if(@show_action, do: "mb-4", else: "mb-0"),
            "text-gray-500"
          ]}>
            {@description}
          </p>
        <% end %>
        <%= if @show_action do %>
          <button
            phx-click={@action_event}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
          >
            {@action_text}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # CSS Helper functions
  defp pagination_button_classes(:active), do: "px-3 py-2 border rounded-md bg-blue-600 text-white border-blue-600"

  defp pagination_button_classes(:inactive),
    do: "px-3 py-2 border rounded-md text-gray-500 hover:text-gray-700 border-gray-300 hover:bg-gray-50"

  defp pagination_button_classes(:ellipsis), do: "px-3 py-2 text-gray-400"

  # Pagination range helper - same logic used across all pages
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
end
