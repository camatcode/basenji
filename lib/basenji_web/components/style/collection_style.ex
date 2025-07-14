defmodule BasenjiWeb.Style.CollectionStyle do
  @privdoc """
  **collection_card_container**: Outer wrapper for collection cards

  * `group`: enables group-hover states for child elements (title color change)
  * `cursor-pointer`: shows hand cursor indicating clickability
  """
  def collection_card_classes(:container), do: "group cursor-pointer"

  @privdoc """
  **collection_card_inner**: Main card styling with hover effects

  * `bg-white rounded-lg`: clean white card with soft corners
  * `shadow-sm border border-gray-200`: subtle elevation and border
  * `p-6`: generous padding (24px) since collections have more text content than comics
  * `hover:shadow-md`: slightly stronger shadow on hover for interactivity
  * `transition-shadow`: smooth animation between shadow states
  * `h-full`: fills available height for consistent grid alignment
  """
  def collection_card_classes(:inner),
    do: "bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow h-full"

  @privdoc """
  **collection_content_layout**: Horizontal layout for icon and text content

  * `flex items-start`: horizontal layout with top alignment (icon stays at top even with long descriptions)
  * `gap-4`: comfortable space (16px) between icon and text
  """
  def collection_card_classes(:content_layout), do: "flex items-start gap-4"

  @privdoc """
  **collection_icon_container**: Container that prevents icon from shrinking

  * `flex-shrink-0`: prevents icon container from getting smaller when text is long
  """
  def collection_card_classes(:icon_container), do: "flex-shrink-0"

  @privdoc """
  **collection_icon_background**: Yellow circular background for folder icon

  * `w-12 h-12`: medium size container (48px) - larger than comic cards since collections are more important
  * `bg-yellow-100`: light yellow background (folders are traditionally yellow)
  * `rounded-lg`: soft rounded corners (not circular like buttons)
  * `flex items-center justify-center`: centers the folder icon
  """
  def collection_card_classes(:icon_background),
    do: "w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center"

  @privdoc """
  **collection_folder_icon**: The actual folder icon

  * `h-7 w-7`: slightly smaller than container (28px in 48px container)
  * `text-yellow-600`: darker yellow for good contrast against light background
  """
  def collection_card_classes(:folder_icon), do: "h-7 w-7 text-yellow-600"

  @privdoc """
  **collection_text_container**: Text content area that can shrink/grow

  * `flex-1`: takes up remaining space after icon
  * `min-w-0`: allows content to shrink below its natural size (enables text truncation)
  """
  def collection_card_classes(:text_container), do: "flex-1 min-w-0"

  @privdoc """
  **collection_title**: Main collection title with hover effects

  * `font-semibold`: bolder than comic titles since collections are more important
  * `text-gray-900`: dark gray for good readability
  * `group-hover:text-blue-600`: title turns blue when card is hovered
  * `transition-colors`: smooth color change animation
  * `mb-2`: small bottom margin (8px) for spacing to description
  """
  def collection_card_classes(:title),
    do: "font-semibold text-gray-900 group-hover:text-blue-600 transition-colors mb-2"

  @privdoc """
  **collection_description**: Optional description text with line clamping

  * `text-sm`: small text size (14px) - same as comic titles but less prominent
  * `text-gray-600`: medium gray (darker than comic metadata, lighter than title)
  * `mb-3`: bottom margin (12px) for spacing to metadata row
  * `line-clamp-3`: truncates to 3 lines with ellipsis if too long (more than comics since collections have more space)
  """
  def collection_card_classes(:description), do: "text-sm text-gray-600 mb-3 line-clamp-3"

  @privdoc """
  **collection_metadata_row**: Container for comic count and date info

  * `flex items-center justify-between`: spreads count and date to opposite ends
  * `text-xs text-gray-500`: extra small light gray text for tertiary information
  """
  def collection_card_classes(:metadata_row), do: "flex items-center justify-between text-xs text-gray-500"
end
