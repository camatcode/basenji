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
    <div class={[container_classes(:search_bar), @class]}>
      <div class="flex flex-col lg:flex-row gap-6">
        <!-- Search -->
        <div class="flex-1">
          <.form for={%{}} phx-submit="search" class="relative">
            <input
              type="text"
              name="search"
              value={@search_query}
              placeholder={@search_placeholder}
              class={search_input_classes()}
            />
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
            </div>
          </.form>
        </div>
        
    <!-- Custom Filters -->
        <%= for {filter_type, filter_label, filter_options, current_value} <- @filter_options do %>
          <div class="lg:w-48">
            <select phx-change={filter_type} name={filter_type} class={form_input_classes()}>
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
            <select phx-change="sort" name="sort" class={form_input_classes()}>
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
          <button phx-click={@clear_event} class={button_classes(:secondary)}>
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
    <div class={[container_classes(:empty_state), @class]}>
      <div class={[
        container_classes(:empty_state_inner),
        if(@style == :dashed, do: card_classes(:dashed), else: card_classes(:default))
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
          <button phx-click={@action_event} class={button_classes(:primary)}>
            {@action_text}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # CSS Helper functions

  # Pagination button styles
  # Active: Blue background with white text for current page
  # - px-3 py-2: Horizontal 12px, vertical 8px padding
  # - border rounded-md: 1px border with medium border radius
  # - bg-blue-600 text-white border-blue-600: Blue background, white text, blue border
  defp pagination_button_classes(:active), do: "px-3 py-2 border rounded-md bg-blue-600 text-white border-blue-600"

  # Inactive: Gray text with hover states for non-current pages
  # - px-3 py-2: Horizontal 12px, vertical 8px padding
  # - border rounded-md: 1px border with medium border radius
  # - text-gray-500: Medium gray text color
  # - hover:text-gray-700: Darker gray text on hover
  # - border-gray-300: Light gray border
  # - hover:bg-gray-50: Very light gray background on hover
  defp pagination_button_classes(:inactive),
    do: "px-3 py-2 border rounded-md text-gray-500 hover:text-gray-700 border-gray-300 hover:bg-gray-50"

  # Ellipsis: Simple gray text for "..." separators
  # - px-3 py-2: Same padding as buttons for alignment
  # - text-gray-400: Light gray text (non-interactive)
  defp pagination_button_classes(:ellipsis), do: "px-3 py-2 text-gray-400"

  # Form input styles (select dropdowns, text inputs)
  # Standard form input styling with focus states
  # - w-full: Full width of container
  # - px-3 py-2: Horizontal 12px, vertical 8px padding
  # - border border-gray-300: 1px light gray border
  # - rounded-lg: Large border radius (8px)
  # - focus:ring-2 focus:ring-blue-500: Blue focus ring on focus
  # - focus:border-blue-500: Blue border on focus
  defp form_input_classes,
    do: "w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

  # Search input with icon spacing
  # Same as form input but with left padding for search icon
  # - pl-10: Left padding 40px (space for magnifying glass icon)
  # - pr-4: Right padding 16px
  # - py-2: Vertical 8px padding
  defp search_input_classes,
    do:
      "w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

  # Button variants
  # Secondary: Gray outline button for less important actions
  # - px-4 py-2: Horizontal 16px, vertical 8px padding
  # - text-gray-600: Medium-dark gray text
  # - hover:text-gray-800: Darker gray text on hover
  # - border border-gray-300: Light gray border
  # - rounded-lg: Large border radius
  # - hover:bg-gray-50: Light gray background on hover
  defp button_classes(:secondary),
    do: "px-4 py-2 text-gray-600 hover:text-gray-800 border border-gray-300 rounded-lg hover:bg-gray-50"

  # Primary: Blue filled button for main actions
  # - inline-flex items-center: Inline flexbox for icon+text alignment
  # - px-4 py-2: Horizontal 16px, vertical 8px padding
  # - border border-transparent: Transparent border (maintains size)
  # - text-sm font-medium: Small text, medium font weight
  # - rounded-md: Medium border radius
  # - text-white: White text
  # - bg-blue-600: Blue background
  # - hover:bg-blue-700: Darker blue on hover
  defp button_classes(:primary),
    do:
      "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"

  # Card container styles
  # Default: Standard white card with subtle shadow
  # - bg-white: White background
  # - rounded-lg: Large border radius (8px)
  # - shadow-sm: Small box shadow
  # - border border-gray-200: Very light gray border
  defp card_classes(:default), do: "bg-white rounded-lg shadow-sm border border-gray-200"

  # Dashed: Dashed border variant for empty states/dropzones
  # - border-2: 2px border width
  # - border-dashed: Dashed border style
  # - border-gray-300: Light gray border color
  # - rounded-lg: Large border radius
  defp card_classes(:dashed), do: "border-2 border-dashed border-gray-300 rounded-lg"

  # Container layout styles
  # Search bar: White card container with padding
  # - bg-white rounded-lg shadow-sm border border-gray-200: Standard card styling
  # - p-6: All-around 24px padding
  defp container_classes(:search_bar), do: "bg-white rounded-lg shadow-sm border border-gray-200 p-6"

  # Empty state: Centered container with vertical spacing
  # - text-center: Center-aligned text
  # - py-12: Vertical 48px padding (top and bottom)
  defp container_classes(:empty_state), do: "text-center py-12"

  # Empty state inner: Padding for content inside empty state card
  # - p-8: All-around 32px padding
  defp container_classes(:empty_state_inner), do: "p-8"

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
