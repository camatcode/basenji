defmodule BasenjiWeb.Live.Style.HomeStyle do
  Module.register_attribute(__MODULE__, :privdoc, accumulate: true)

  @privdoc """
  **page_container**: Main container for home page with max width constraint

  * `max-w-7xl`: generous max width (1280px) for dashboard-style layout
  * `mx-auto`: centers the container on larger screens
  """
  def home_live_classes(:page_container), do: "max-w-7xl mx-auto"

  @privdoc """
  **page_container**: Main container for home page with max width constraint

  * `max-w-7xl`: generous max width (1280px) for dashboard-style layout
  * `mx-auto`: centers the container on larger screens
  """
  def home_live_classes(:page_container), do: "max-w-7xl mx-auto"

  @privdoc """
  **header_section**: Container for entire header area with bottom spacing

  * `mb-8`: generous bottom margin (32px) to separate header from content
  """
  def home_live_classes(:header_section), do: "mb-8"

  @privdoc """
  **header_layout**: Layout for title/stats and search bar

  * `flex flex-col lg:flex-row`: stacks vertically on mobile, horizontal on large screens
  * `lg:items-center lg:justify-between`: on large screens, centers and spreads apart
  * `gap-6`: consistent spacing (24px) between header elements
  """
  def home_live_classes(:header_layout), do: "flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6"

  @privdoc """
  **page_title**: Main "Home" title

  * `text-3xl font-bold text-gray-900`: large, bold, dark text for primary heading
  """
  def home_live_classes(:page_title), do: "text-3xl font-bold text-gray-900"

  @privdoc """
  **page_stats**: Summary stats below title (X comics • Y collections)

  * `text-gray-600 mt-1`: medium gray with tight coupling to title
  """
  def home_live_classes(:page_stats), do: "text-gray-600 mt-1"

  @privdoc """
  **search_bar_container**: Container for search input with width constraint

  * `lg:w-96`: fixed width (384px) on large screens for balanced layout
  """
  def home_live_classes(:search_bar_container), do: "lg:w-96"

  @privdoc """
  **search_form**: Form wrapper for search input (relative for absolute positioned elements)

  * `relative`: allows absolute positioning of icons inside
  """
  def home_live_classes(:search_form), do: "relative"

  @privdoc """
  **search_input**: Main search input field with icon spacing

  * `w-full`: full width of container
  * `pl-10 pr-10`: left padding for search icon, right padding for clear button
  * `py-2`: vertical padding for comfortable input height
  * Standard input styling with focus states
  """
  def home_live_classes(:search_input),
    do:
      "w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

  @privdoc """
  **search_icon_container**: Container for search magnifying glass icon

  * `absolute inset-y-0 left-0`: positioned at left edge, full height
  * `pl-3`: padding to position icon nicely
  * `flex items-center`: centers icon vertically
  * `pointer-events-none`: icon doesn't interfere with input clicks
  """
  def home_live_classes(:search_icon_container),
    do: "absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none"

  @privdoc """
  **search_icon**: Magnifying glass icon styling

  * `h-5 w-5`: medium icon size
  * `text-gray-400`: light gray to indicate helper element
  """
  def home_live_classes(:search_icon), do: "h-5 w-5 text-gray-400"

  @privdoc """
  **search_clear_button**: Clear search button (X icon)

  * `absolute inset-y-0 right-0`: positioned at right edge, full height
  * `pr-3`: padding to position button nicely
  * `flex items-center`: centers button vertically
  """
  def home_live_classes(:search_clear_button), do: "absolute inset-y-0 right-0 pr-3 flex items-center"

  @privdoc """
  **search_clear_icon**: X icon for clearing search

  * `h-5 w-5`: medium icon size
  * `text-gray-400 hover:text-gray-600`: light gray with darker hover
  """
  def home_live_classes(:search_clear_icon), do: "h-5 w-5 text-gray-400 hover:text-gray-600"

  @privdoc """
  **search_results_container**: Container for search results section

  * `mb-8`: bottom margin (32px) for spacing from other content
  """
  def home_live_classes(:search_results_container), do: "mb-8"

  @privdoc """
  **search_results_header**: Header card for search results

  * `bg-blue-50 border border-blue-200`: light blue background with border
  * `rounded-lg p-4 mb-6`: rounded corners with padding and bottom spacing
  """
  def home_live_classes(:search_results_header), do: "bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6"

  @privdoc """
  **search_results_title**: "Search Results for..." title

  * `text-lg font-semibold text-blue-900 mb-2`: large, bold blue text with spacing
  """
  def home_live_classes(:search_results_title), do: "text-lg font-semibold text-blue-900 mb-2"

  @privdoc """
  **search_section**: Container for each search result section (comics, collections)

  * `mb-6`: bottom margin (24px) between different result types
  """
  def home_live_classes(:search_section), do: "mb-6"

  @privdoc """
  **search_section_title**: Section titles for search results

  * `text-lg font-semibold text-gray-900 mb-4`: large, bold with bottom spacing
  """
  def home_live_classes(:search_section_title), do: "text-lg font-semibold text-gray-900 mb-4"

  @privdoc """
  **search_comics_grid**: Grid for comic search results

  * `grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4`: responsive grid
    - 2 columns on mobile (comics are narrow)
    - 3 columns on small screens
    - 4 columns on medium+ screens
  * `gap-6`: consistent spacing between cards
  """
  def home_live_classes(:search_comics_grid), do: "grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4 gap-6"

  @privdoc """
  **search_collections_grid**: Grid for collection search results

  * `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3`: responsive grid
    - 1 column on mobile (collections need more width)
    - 2 columns on small screens
    - 3 columns on large screens
  * `gap-6`: consistent spacing between cards
  """
  def home_live_classes(:search_collections_grid), do: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6"

  @privdoc """
  **no_results_container**: Container for "no search results" message

  * `text-center text-gray-500 py-8`: centered, gray text with vertical padding
  """
  def home_live_classes(:no_results_container), do: "text-center text-gray-500 py-8"

  @privdoc """
  **no_results_icon**: Large magnifying glass for no results state

  * `h-12 w-12`: large icon (48px)
  * `mx-auto mb-4`: centered horizontally with bottom spacing
  * `text-gray-300`: very light gray for subtle appearance
  """
  def home_live_classes(:no_results_icon), do: "h-12 w-12 mx-auto mb-4 text-gray-300"

  @privdoc """
  **content_section**: Container for main content sections (recent comics, collections)

  * `mb-8`: bottom margin (32px) between major sections
  """
  def home_live_classes(:content_section), do: "mb-8"

  @privdoc """
  **section_header**: Header for content sections

  * `flex items-center justify-between mb-4`: spreads title and "view all" link
  """
  def home_live_classes(:section_header), do: "flex items-center justify-between mb-4"

  @privdoc """
  **section_title**: Title for content sections (Recent Comics, Collections)

  * `text-xl font-semibold text-gray-900`: large, bold section title
  """
  def home_live_classes(:section_title), do: "text-xl font-semibold text-gray-900"

  @privdoc """
  **section_view_all_link**: "View all →" links to full pages

  * `text-blue-600 hover:text-blue-700`: blue link with darker hover
  * `font-medium`: slightly bolder for prominence
  """
  def home_live_classes(:section_view_all_link), do: "text-blue-600 hover:text-blue-700 font-medium"

  @privdoc """
  **recent_comics_grid**: Grid for recent comics on home page

  * `grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4`: responsive grid
    - Same as search comics grid for consistency
  * `gap-6`: consistent spacing
  """
  def home_live_classes(:recent_comics_grid), do: "grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4 gap-6"

  @privdoc """
  **recent_collections_grid**: Grid for collections on home page

  * `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4`: responsive grid
    - 1 column on mobile
    - 2 columns on small screens
    - 3 columns on large screens
    - 4 columns on extra large screens (more space on home)
  * `gap-6`: consistent spacing
  """
  def home_live_classes(:recent_collections_grid),
    do: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"

  @privdoc """
  **empty_state_override**: Custom styling for empty states on home page

  * `py-8`: reduced vertical padding since these are secondary content areas
  """
  def home_live_classes(:empty_state_override), do: "py-8"

  @privdoc """
  **empty_state_icon**: Icons for empty states on home page

  * `h-12 w-12`: large but not overwhelming icon size
  """
  def home_live_classes(:empty_state_icon), do: "h-12 w-12"
end
