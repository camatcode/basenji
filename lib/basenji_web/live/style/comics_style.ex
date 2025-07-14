defmodule BasenjiWeb.Live.Style.ComicsStyle do
  @moduledoc false
  Module.register_attribute(__MODULE__, :privdoc, accumulate: true)

  @privdoc """
  **header_layout**: Layout for page headers (used in index page)

  * `flex flex-col lg:flex-row`: stacks vertically on mobile, horizontal on large screens
  * `lg:items-center lg:justify-between`: on large screens, centers vertically and spreads apart
  * `gap-6`: slightly larger gap (24px) than collections since this might have action buttons
  """
  def comics_live_classes(:header_layout), do: "flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6"

  @privdoc """
  **comics_grid**: Grid layout for comic cards on index page

  * `grid`: CSS grid layout
  * `grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4 xl:grid-cols-5`: responsive columns
    - 2 columns on mobile (comics are narrower than collections)
    - 3 columns on small screens
    - 4 columns on medium and large screens
    - 5 columns on extra large screens (more comics can fit)
  * `gap-6`: consistent spacing (24px) between cards
  """
  def comics_live_classes(:comics_grid),
    do: "grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4 xl:grid-cols-5 gap-6"

  @privdoc """
  **show_page_container**: Wide container for comic show pages

  * `max-w-8xl`: very wide max width to accommodate comic reader
  * `mx-auto`: centers the container
  * `space-y-6`: consistent vertical spacing
  """
  def comics_live_classes(:show_page_container), do: "max-w-8xl mx-auto space-y-6"

  @privdoc """
  **details_grid**: Main layout grid for comic show page (non-reader view)

  * `grid grid-cols-1 lg:grid-cols-3`: single column on mobile, 3 columns on large screens
  * `gap-8`: generous spacing (32px) between cover and details sections
  """
  def comics_live_classes(:details_grid), do: "grid grid-cols-1 lg:grid-cols-3 gap-8"

  @privdoc """
  **cover_section**: Container for comic cover and action buttons

  * `space-y-4`: consistent spacing (16px) between cover and buttons
  """
  def comics_live_classes(:cover_section), do: "space-y-4"

  @privdoc """
  **details_section**: Container for comic details and collections

  * `lg:col-span-2`: takes up 2 of 3 grid columns on large screens
  * `space-y-6`: consistent spacing (24px) between detail sections
  """
  def comics_live_classes(:details_section), do: "lg:col-span-2 space-y-6"

  @privdoc """
  **cover_card**: Card container for comic cover image

  * Uses standard card styling
  * `bg-white rounded-lg shadow-sm border border-gray-200`: clean card appearance
  * `overflow-hidden`: ensures image doesn't break card boundaries
  """
  def comics_live_classes(:cover_card), do: "bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden"

  @privdoc """
  **cover_image_container**: Container maintaining aspect ratio for cover

  * `aspect-[3/4]`: maintains 3:4 aspect ratio (standard comic proportions)
  * `bg-gradient-to-br from-blue-50 to-blue-100`: subtle gradient fallback
  * `flex items-center justify-center`: centers fallback icon
  """
  def comics_live_classes(:cover_image_container),
    do: "aspect-[3/4] bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center"

  @privdoc """
  **cover_image**: Styling for the cover image

  * `w-full h-full object-cover`: fills container maintaining aspect ratio
  """
  def comics_live_classes(:cover_image), do: "w-full h-full object-cover"

  @privdoc """
  **cover_fallback_icon**: Large icon when no cover is available

  * `h-16 w-16`: large icon (64px) for prominent fallback
  * `text-blue-400`: light blue to match gradient
  """
  def comics_live_classes(:cover_fallback_icon), do: "h-16 w-16 text-blue-400"

  @privdoc """
  **action_buttons_container**: Container for comic action buttons

  * `space-y-2`: small spacing (8px) between stacked buttons
  """
  def comics_live_classes(:action_buttons_container), do: "space-y-2"

  @privdoc """
  **primary_action_button**: Main "Read Comic" button styling

  * `w-full`: full width of container
  * `bg-blue-600 text-white`: blue background with white text
  * `px-4 py-3`: comfortable padding (16px horizontal, 12px vertical)
  * `rounded-lg`: rounded corners
  * `hover:bg-blue-700`: darker blue on hover
  * `transition-colors`: smooth color transition
  * `font-medium`: slightly bolder text
  """
  def comics_live_classes(:primary_action_button),
    do: "w-full bg-blue-600 text-white px-4 py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium"

  @privdoc """
  **secondary_action_button**: Secondary action buttons (optimized, original versions)

  * `w-full`: full width of container
  * `px-4 py-3`: same padding as primary for consistency
  * `rounded-lg transition-colors font-medium`: same styling as primary
  * `text-center block`: ensures link buttons look like buttons
  """
  def comics_live_classes(:secondary_action_button_green),
    do:
      "w-full bg-green-600 text-white px-4 py-3 rounded-lg hover:bg-green-700 transition-colors font-medium text-center block"

  def comics_live_classes(:secondary_action_button_gray),
    do:
      "w-full bg-gray-600 text-white px-4 py-3 rounded-lg hover:bg-gray-700 transition-colors font-medium text-center block"

  @privdoc """
  **action_button_icon**: Icons inside action buttons

  * `h-5 w-5 inline mr-2`: medium icon with right margin, inline with text
  """
  def comics_live_classes(:action_button_icon), do: "h-5 w-5 inline mr-2"

  @privdoc """
  **metadata_card**: Card container for comic metadata

  * `bg-white rounded-lg shadow-sm border border-gray-200 p-6`: standard card with generous padding
  """
  def comics_live_classes(:metadata_card), do: "bg-white rounded-lg shadow-sm border border-gray-200 p-6"

  @privdoc """
  **comic_title**: Large title for comic detail page

  * `text-3xl font-bold text-gray-900 mb-4`: large, bold title with bottom spacing
  """
  def comics_live_classes(:comic_title), do: "text-3xl font-bold text-gray-900 mb-4"

  @privdoc """
  **metadata_grid**: Grid layout for comic metadata fields

  * `grid grid-cols-2 md:grid-cols-4`: responsive grid
    - 2 columns on mobile (stacked metadata)
    - 4 columns on medium+ screens (spread out metadata)
  * `gap-4 text-sm`: consistent spacing with small text
  """
  def comics_live_classes(:metadata_grid), do: "grid grid-cols-2 md:grid-cols-4 gap-4 text-sm"

  @privdoc """
  **metadata_label**: Styling for metadata field labels

  * `font-medium text-gray-500`: slightly bold, medium gray for labels
  """
  def comics_live_classes(:metadata_label), do: "font-medium text-gray-500"

  @privdoc """
  **metadata_value**: Styling for metadata field values

  * `text-gray-900`: dark gray for good readability
  """
  def comics_live_classes(:metadata_value), do: "text-gray-900"

  @privdoc """
  **metadata_value_uppercase**: Styling for values that should be uppercase (format)

  * `text-gray-900 uppercase`: dark gray with uppercase transformation
  """
  def comics_live_classes(:metadata_value_uppercase), do: "text-gray-900 uppercase"

  @privdoc """
  **description_section**: Container for comic description

  * `mt-6`: top margin (24px) to separate from metadata grid
  """
  def comics_live_classes(:description_section), do: "mt-6"

  @privdoc """
  **description_heading**: Heading for description section

  * `font-medium text-gray-900 mb-2`: medium weight, dark gray with bottom spacing
  """
  def comics_live_classes(:description_heading), do: "font-medium text-gray-900 mb-2"

  @privdoc """
  **description_text**: Comic description text styling

  * `text-gray-700 leading-relaxed`: slightly lighter than headings with increased line height
  """
  def comics_live_classes(:description_text), do: "text-gray-700 leading-relaxed"

  @privdoc """
  **collections_section_heading**: Heading for collections management section

  * `font-medium text-gray-900 mb-4`: medium weight with bottom spacing
  """
  def comics_live_classes(:collections_section_heading), do: "font-medium text-gray-900 mb-4"

  @privdoc """
  **collection_tags_container**: Container for current collection tags

  * `flex flex-wrap gap-2 mb-4`: flexible wrapping layout with consistent spacing
  """
  def comics_live_classes(:collection_tags_container), do: "flex flex-wrap gap-2 mb-4"

  @privdoc """
  **collection_tag**: Individual collection tag styling

  * `flex items-center gap-2`: horizontal layout for tag content
  * `bg-blue-100 text-blue-800`: light blue background with darker blue text
  * `px-3 py-1`: compact padding
  * `rounded-full text-sm`: pill shape with small text
  """
  def comics_live_classes(:collection_tag),
    do: "flex items-center gap-2 bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm"

  @privdoc """
  **collection_tag_link**: Link styling within collection tags

  * `hover:underline`: simple underline on hover
  """
  def comics_live_classes(:collection_tag_link), do: "hover:underline"

  @privdoc """
  **collection_tag_remove**: Remove button within collection tags

  * `text-blue-600 hover:text-blue-800`: blue text that darkens on hover
  """
  def comics_live_classes(:collection_tag_remove), do: "text-blue-600 hover:text-blue-800"

  @privdoc """
  **collection_tag_icon**: Icon for remove button in tags

  * `h-4 w-4`: small icon (16px) for compact tags
  """
  def comics_live_classes(:collection_tag_icon), do: "h-4 w-4"

  @privdoc """
  **add_collection_form**: Form layout for adding to collections

  * `flex gap-2`: horizontal layout with spacing between select and button
  """
  def comics_live_classes(:add_collection_form), do: "flex gap-2"

  @privdoc """
  **add_collection_select**: Dropdown for selecting collections

  * `flex-1`: takes up remaining space after button
  * Standard form input styling with focus states
  """
  def comics_live_classes(:add_collection_select),
    do: "flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

  @privdoc """
  **add_collection_button**: Button for adding to selected collection

  * `px-4 py-2`: comfortable button padding
  * `bg-blue-600 text-white`: blue background with white text
  * `rounded-lg hover:bg-blue-700 transition-colors`: rounded with hover effect
  """
  def comics_live_classes(:add_collection_button),
    do: "px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"

  @privdoc """
  **no_collections_message**: Message when no collections are available

  * `text-gray-500 text-sm`: light gray, small text for secondary information
  """
  def comics_live_classes(:no_collections_message), do: "text-gray-500 text-sm"

  # Reader-specific styles
  @privdoc """
  **reader_container**: Full reader container with black background

  * `bg-black rounded-lg overflow-hidden`: dark theme with rounded corners
  """
  def comics_live_classes(:reader_container), do: "bg-black rounded-lg overflow-hidden"

  @privdoc """
  **reader_header**: Header bar for comic reader

  * `bg-gray-900 px-4 py-3`: dark gray background with padding
  * `flex items-center justify-between`: spreads content across header
  """
  def comics_live_classes(:reader_header), do: "bg-gray-900 px-4 py-3 flex items-center justify-between"

  @privdoc """
  **reader_header_left**: Left side of reader header (close button, title)

  * `flex items-center gap-4 text-white`: horizontal layout with white text
  """
  def comics_live_classes(:reader_header_left), do: "flex items-center gap-4 text-white"

  @privdoc """
  **reader_close_button**: Close reader button

  * `flex items-center gap-2 hover:text-gray-300`: layout with hover effect
  """
  def comics_live_classes(:reader_close_button), do: "flex items-center gap-2 hover:text-gray-300"

  @privdoc """
  **reader_title**: Comic title in reader header

  * `text-sm`: small text to fit in compact header
  """
  def comics_live_classes(:reader_title), do: "text-sm"

  @privdoc """
  **reader_navigation**: Page navigation controls

  * `flex items-center gap-4 text-white text-sm`: horizontal layout with white text
  """
  def comics_live_classes(:reader_navigation), do: "flex items-center gap-4 text-white text-sm"

  @privdoc """
  **reader_nav_button**: Previous/next page buttons

  * `hover:text-gray-300 disabled:opacity-50`: hover effect with disabled state
  """
  def comics_live_classes(:reader_nav_button), do: "hover:text-gray-300 disabled:opacity-50"

  @privdoc """
  **reader_nav_icon**: Icons for navigation buttons

  * `h-5 w-5`: medium icons for good click targets
  """
  def comics_live_classes(:reader_nav_icon), do: "h-5 w-5"

  @privdoc """
  **reader_page_input_container**: Container for page input controls

  * `flex items-center gap-2`: horizontal layout for input and text
  """
  def comics_live_classes(:reader_page_input_container), do: "flex items-center gap-2"

  @privdoc """
  **reader_page_input**: Page number input field

  * `w-16 px-2 py-1`: narrow width for page numbers with minimal padding
  * `text-black rounded text-center`: black text, rounded corners, centered
  """
  def comics_live_classes(:reader_page_input), do: "w-16 px-2 py-1 text-black rounded text-center"

  @privdoc """
  **reader_page_display**: Main page display area

  * `flex justify-center items-center`: centers the comic page
  * `min-h-[80vh] p-4`: takes up most of viewport height with padding
  """
  def comics_live_classes(:reader_page_display), do: "flex justify-center items-center min-h-[80vh] p-4"

  @privdoc """
  **reader_page_image**: The actual comic page image

  * `max-w-full max-h-full object-contain`: fits within container while maintaining aspect ratio
  """
  def comics_live_classes(:reader_page_image), do: "max-w-full max-h-full object-contain"
end
