defmodule BasenjiWeb.Style.SharedStyle do
  @moduledoc false
  Module.register_attribute(__MODULE__, :privdoc, accumulate: true)

  @privdoc """
   **active**: highlights the current page number (e.g page 3 of 10)

    * `px-3 py-2`: comfortable click target with 12px left/right, 8px top/bottom padding
    * `border rounded-md`: thin border with slightly rounded corners (not too round)
    * `bg-blue-600`:  blue background to make it obvious this is "where you are"
  """
  def pagination_button_classes(:active), do: "px-3 py-2 border rounded-md bg-blue-600 text-white border-blue-600"

  @privdoc """
  **inactive**: Other page buttons - clearly clickable but don't compete with current page

   * px-3 py-2: Same padding as buttons for alignment
   * hover states: text gets darker, background gets light gray on mouse-over
  """
  def pagination_button_classes(:inactive),
    do: "px-3 py-2 border rounded-md text-gray-500 hover:text-gray-700 border-gray-300 hover:bg-gray-50"

  @privdoc """
  **ellipsis**: Simple gray text for "..." separators

   * `px-3 py-2`: Same padding as buttons for alignment
   * `text-gray-400`: Light gray text (non-interactive)
  """
  def pagination_button_classes(:ellipsis), do: "px-3 py-2 text-gray-400"

  @privdoc """
  **form_input_classes**: Standard styling for all form inputs (dropdowns, text fields)

  * `w-full`: stretches to fill available space
  * `px-3 py-2`: same comfortable padding as our buttons
  * `border border-gray-300`: subtle gray border
  * `rounded-lg`: slightly more rounded than buttons for softer feel
  * `focus:ring-2 focus:ring-blue-500`: blue glow around input when clicked/tabbed to
  * `focus:border-blue-500`: border also turns blue on focus
  """
  def form_input_classes,
    do: "w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

  @privdoc """
  **search_input_classes**: Form input with extra space for magnifying glass icon

  * `pl-10`: 40px left padding makes room for search icon
  * `pr-4`: normal right padding (16px)
  * Everything else same as regular form inputs
  """
  def search_input_classes,
    do:
      "w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

  @privdoc """
  **secondary**: Subtle button for less important actions (Cancel, Clear filters)

  * `px-4 py-2`: slightly more padding than form inputs (buttons need more space)
  * `text-gray-600`: medium gray text that's clearly clickable
  * `hover:text-gray-800`: darker gray on hover
  * `border border-gray-300`: subtle outline
  * `hover:bg-gray-50`: very light background change on hover
  """
  def button_classes(:secondary),
    do: "px-4 py-2 text-gray-600 hover:text-gray-800 border border-gray-300 rounded-lg hover:bg-gray-50"

  @privdoc """
  **primary**: Bold button for main actions (Save, Submit, Create)

  * `inline-flex items-center`: needed if button contains icon + text
  * `px-4 py-2`: comfortable click target
  * `border border-transparent`: invisible border maintains consistent sizing
  * `text-sm font-medium`: slightly smaller, bolder text
  * `rounded-md`: medium rounded corners (less than cards)
  * `bg-blue-600`: our brand blue, stands out from everything else
  * `hover:bg-blue-700`: darker blue on hover (standard pattern)
  """
  def button_classes(:primary),
    do:
      "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"

  @privdoc """
  **default**: Standard white content card with subtle shadow

  * `bg-white`: clean white background
  * `rounded-lg`: soft rounded corners for container feel
  * `shadow-sm`: very light drop shadow (not dramatic)
  * `border border-gray-200`: extremely subtle border
  """
  def card_classes(:default), do: "bg-white rounded-lg shadow-sm border border-gray-200"

  @privdoc """
  **dashed**: Empty state card that suggests "drop something here"

  * `border-2`: thicker border so dashes are clearly visible
  * `border-dashed`: dotted line style suggests interactivity
  * `border-gray-300`: light gray so it doesn't dominate
  * `rounded-lg`: same rounding as default cards
  * No background color - draws less attention than solid cards
  """
  def card_classes(:dashed), do: "border-2 border-dashed border-gray-300 rounded-lg"

  @privdoc """
  **search_bar**: Container for search and filter controls

  * Uses standard card styling plus generous padding
  * `p-6`: 24px padding on all sides since this contains multiple form elements
  """
  def container_classes(:search_bar), do: "bg-white rounded-lg shadow-sm border border-gray-200 p-6"

  @privdoc """
  **empty_state**: Wrapper for empty state content

  * `text-center`: centers icon, title, and description
  * `py-12`: lots of vertical space (48px top/bottom) so empty states don't feel cramped
  """
  def container_classes(:empty_state), do: "text-center py-12"

  @privdoc """
  **empty_state_inner**: Padding around empty state content inside the card

  * `p-8`: comfortable padding (32px) around icon and text
  """
  @doc false
  def container_classes(:empty_state_inner), do: "p-8"

  @privdoc """
  **container**: Standard page container with consistent spacing

  * `space-y-6`: consistent vertical spacing (24px) between major page sections
  """
  @doc false
  def page_classes(:container), do: "space-y-6"

  @privdoc """
  **title**: Main page title styling

  * `text-3xl font-bold text-gray-900`: large, bold, dark text for primary headings
  """
  @doc false
  def page_classes(:title), do: "text-3xl font-bold text-gray-900"

  @privdoc """
  **subtitle**: Subtitle with count or additional info

  * `text-gray-600 mt-1`: medium gray with tight coupling to title
  """
  @doc false
  def page_classes(:subtitle), do: "text-gray-600 mt-1"

  @privdoc """
  **header_layout**: Layout for page headers with title and optional actions

  * `flex flex-col lg:flex-row`: stacks vertically on mobile, horizontal on large screens
  * `lg:items-center lg:justify-between`: on large screens, centers vertically and spreads apart
  * `gap-4`: consistent spacing (16px) between header elements
  """
  @doc false
  def page_classes(:header_layout), do: "flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4"

  @privdoc """
  **back_link**: Styling for "Back to X" navigation links

  * `inline-flex items-center`: allows icon and text to align properly
  * `text-gray-600 hover:text-gray-900`: medium gray with darker hover
  """
  @doc false
  def navigation_classes(:back_link), do: "inline-flex items-center text-gray-600 hover:text-gray-900"

  @privdoc """
  **back_icon**: Icon styling for back navigation

  * `h-5 w-5 mr-2`: medium icon with right margin for spacing from text
  """
  @doc false
  def navigation_classes(:back_icon), do: "h-5 w-5 mr-2"

  @privdoc """
  **comics_standard**: Standard responsive grid for comic cards

  * `grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4`: responsive columns
    - 2 columns on mobile (comics are narrow)
    - 3 columns on small screens
    - 4 columns on medium+ screens
  * `gap-6`: consistent spacing (24px) between cards
  """
  @doc false
  def grid_classes(:comics_standard), do: "grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4 gap-6"

  @privdoc """
  **collections_standard**: Standard responsive grid for collection cards

  * `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3`: responsive columns
    - 1 column on mobile (collections need more width)
    - 2 columns on small screens
    - 3 columns on large screens
  * `gap-6`: consistent spacing (24px) between cards
  """
  @doc false
  def grid_classes(:collections_standard), do: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6"

  @privdoc """
  **collections_extended**: Extended grid for collection cards with more columns

  * `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4`: responsive columns
    - Same as standard but adds 4th column on extra large screens
  * `gap-6`: consistent spacing (24px) between cards
  """
  @doc false
  def grid_classes(:collections_extended), do: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"

  @privdoc """
  **container**: Container for content sections

  * `mb-8`: bottom margin (32px) between major sections
  """
  @doc false
  def section_classes(:container), do: "mb-8"

  @privdoc """
  **header**: Header for content sections with title and action

  * `flex items-center justify-between mb-4`: spreads title and "view all" link
  """
  @doc false
  def section_classes(:header), do: "flex items-center justify-between mb-4"

  @privdoc """
  **title**: Title for content sections

  * `text-xl font-semibold text-gray-900`: large, bold section title
  """
  @doc false
  def section_classes(:title), do: "text-xl font-semibold text-gray-900"

  @privdoc """
  **view_all_link**: "View all →" links to full pages

  * `text-blue-600 hover:text-blue-700`: blue link with darker hover
  * `font-medium`: slightly bolder for prominence
  """
  @doc false
  def section_classes(:view_all_link), do: "text-blue-600 hover:text-blue-700 font-medium"
end
