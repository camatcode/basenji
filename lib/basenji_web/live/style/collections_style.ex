defmodule BasenjiWeb.Live.Style.CollectionsStyle do
  # Register @privdoc as a valid module attribute to suppress warnings
  Module.register_attribute(__MODULE__, :privdoc, accumulate: true)

  @privdoc """
  **page_container**: Main container for all collections live view pages

  * `space-y-6`: consistent vertical spacing (24px) between major page sections
  """
  def collections_live_classes(:page_container), do: "space-y-6"

  @privdoc """
  **header_layout**: Layout for page headers with title and optional actions

  * `flex flex-col lg:flex-row`: stacks vertically on mobile, horizontal on large screens
  * `lg:items-center lg:justify-between`: on large screens, centers vertically and spreads apart
  * `gap-4`: consistent spacing (16px) between header elements
  """
  def collections_live_classes(:header_layout), do: "flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4"

  @privdoc """
  **page_title**: Main page title styling

  * `text-3xl`: large text (30px) for primary page headings
  * `font-bold`: heavy weight to establish hierarchy
  * `text-gray-900`: darkest gray for maximum readability
  """
  def collections_live_classes(:page_title), do: "text-3xl font-bold text-gray-900"

  @privdoc """
  **page_subtitle**: Subtitle with count or additional info

  * `text-gray-600`: medium gray (less prominent than title)
  * `mt-1`: small top margin (4px) for tight coupling with title
  """
  def collections_live_classes(:page_subtitle), do: "text-gray-600 mt-1"

  @privdoc """
  **collections_grid**: Grid layout for collection cards on index page

  * `grid`: CSS grid layout
  * `grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4`: responsive columns
    - 1 column on mobile (stacked)
    - 2 columns on medium screens (tablets)
    - 3 columns on large screens (small desktops)
    - 4 columns on extra large screens (large desktops)
  * `gap-6`: consistent spacing (24px) between cards
  """
  def collections_live_classes(:collections_grid),
    do: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"

  @privdoc """
  **comics_grid**: Grid layout for comics within a collection (denser layout)

  * `grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8`: 
    - More columns than collections since comic cards are smaller
    - Starts with 2 columns even on mobile (comics are narrow)
    - Goes up to 8 columns on large screens for browsing many comics
  * `gap-4`: smaller gap (16px) since comic cards are smaller
  """
  def collections_live_classes(:comics_grid),
    do: "grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8 gap-4"

  @privdoc """
  **back_link**: Styling for "Back to Collections" navigation link

  * `inline-flex items-center`: allows icon and text to align properly
  * `text-gray-600`: medium gray for secondary navigation
  * `hover:text-gray-900`: darker on hover to show interactivity
  """
  def collections_live_classes(:back_link), do: "inline-flex items-center text-gray-600 hover:text-gray-900"

  @privdoc """
  **back_icon**: Icon styling for back navigation

  * `h-5 w-5`: medium icon size (20px)
  * `mr-2`: right margin (8px) for spacing from text
  """
  def collections_live_classes(:back_icon), do: "h-5 w-5 mr-2"

  @privdoc """
  **collection_detail_header**: Card container for collection information on show page

  * Uses standard card styling with generous padding for important content
  * `bg-white rounded-lg shadow-sm border border-gray-200`: clean card appearance
  * `p-6`: generous padding (24px) since this is the main focus of the page
  """
  def collections_live_classes(:collection_detail_header),
    do: "bg-white rounded-lg shadow-sm border border-gray-200 p-6"

  @privdoc """
  **collection_detail_layout**: Layout for collection icon and information

  * `flex items-start`: horizontal layout with top alignment (icon stays at top even with long descriptions)
  * `gap-4`: comfortable spacing (16px) between icon and text
  """
  def collections_live_classes(:collection_detail_layout), do: "flex items-start gap-4"

  @privdoc """
  **collection_large_icon_container**: Large icon container for collection detail page

  * `w-16 h-16`: larger than card icons (64px) since this is the main collection page
  * `bg-yellow-100 rounded-lg`: yellow background with soft corners
  * `flex items-center justify-center`: centers the folder icon
  * `flex-shrink-0`: prevents shrinking when text content is long
  """
  def collections_live_classes(:collection_large_icon_container),
    do: "w-16 h-16 bg-yellow-100 rounded-lg flex items-center justify-center flex-shrink-0"

  @privdoc """
  **collection_large_icon**: Large folder icon for collection detail page

  * `h-10 w-10`: large icon (40px) proportional to the 64px container
  * `text-yellow-600`: darker yellow for good contrast
  """
  def collections_live_classes(:collection_large_icon), do: "h-10 w-10 text-yellow-600"

  @privdoc """
  **collection_text_content**: Container for collection title and description

  * `flex-1`: takes remaining space after icon
  """
  def collections_live_classes(:collection_text_content), do: "flex-1"

  @privdoc """
  **collection_detail_title**: Large title for collection detail page

  * `text-3xl font-bold`: same as page titles for consistency
  * `text-gray-900`: darkest gray for readability
  * `mb-2`: bottom margin (8px) for spacing to description
  """
  def collections_live_classes(:collection_detail_title), do: "text-3xl font-bold text-gray-900 mb-2"

  @privdoc """
  **collection_description**: Description text for collection detail page

  * `text-gray-600`: medium gray (readable but less prominent than title)
  * `mb-4`: bottom margin (16px) for spacing to metadata
  * `leading-relaxed`: increased line height for better readability of longer text
  """
  def collections_live_classes(:collection_description), do: "text-gray-600 mb-4 leading-relaxed"

  @privdoc """
  **collection_metadata**: Container for collection metadata (count, date, parent)

  * `flex items-center`: horizontal layout with centered alignment
  * `gap-4`: consistent spacing (16px) between metadata items
  * `text-sm text-gray-500`: small, light gray text for secondary information
  """
  def collections_live_classes(:collection_metadata), do: "flex items-center gap-4 text-sm text-gray-500"

  @privdoc """
  **parent_link**: Styling for parent collection links

  * `text-blue-600`: our brand blue for links
  * `hover:text-blue-700`: darker blue on hover (standard link pattern)
  """
  def collections_live_classes(:parent_link), do: "text-blue-600 hover:text-blue-700"
end
