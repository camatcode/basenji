defmodule BasenjiWeb.Style.SharedStyle do
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

  def form_input_classes,
    do: "w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

  def search_input_classes,
    do:
      "w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

  def button_classes(:secondary),
    do: "px-4 py-2 text-gray-600 hover:text-gray-800 border border-gray-300 rounded-lg hover:bg-gray-50"

  def button_classes(:primary),
    do:
      "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"

  def card_classes(:default), do: "bg-white rounded-lg shadow-sm border border-gray-200"

  def card_classes(:dashed), do: "border-2 border-dashed border-gray-300 rounded-lg"

  def container_classes(:search_bar), do: "bg-white rounded-lg shadow-sm border border-gray-200 p-6"

  def container_classes(:empty_state), do: "text-center py-12"

  def container_classes(:empty_state_inner), do: "p-8"
end
