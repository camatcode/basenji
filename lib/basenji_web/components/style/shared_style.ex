defmodule BasenjiWeb.Style.SharedStyle do
  # Register @privdoc as a valid module attribute to suppress warnings
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
  def container_classes(:empty_state_inner), do: "p-8"
end
