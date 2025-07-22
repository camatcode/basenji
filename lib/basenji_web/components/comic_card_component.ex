defmodule BasenjiWeb.ComicCardComponent do
  @moduledoc false
  use BasenjiWeb, :live_component

  Module.register_attribute(__MODULE__, :privdoc, accumulate: true)

  attr :comic, :any, required: true, doc: "The comic struct to display"
  attr :class, :string, default: "", doc: "Additional CSS classes for the card container"
  attr :lazy_loading, :boolean, default: true, doc: "Whether to use lazy loading for images"

  def render(assigns) do
    ~H"""
    <div class={[comic_card_classes(:container), @class]}>
      <div class={comic_card_classes(:inner)}>
        <.link navigate={~p"/comics/#{@comic.id}/read"} class="block">
          <div class={comic_card_classes(:cover_container)}>
            <%= if @comic.image_preview do %>
              <img
                id={@comic.id <> "_preview"}
                src={~p"/api/comics/#{@comic.id}/preview"}
                alt={@comic.title || "Unknown"}
                class={comic_card_classes(:cover_image)}
                loading={if @lazy_loading, do: "lazy", else: "eager"}
              />
            <% else %>
              <.icon name="hero-book-open" class={comic_card_classes(:fallback_icon)} />
            <% end %>
          </div>
        </.link>

        <div class={comic_card_classes(:content_area)}>
          <h3 class={comic_card_classes(:title)}>
            {String.replace(@comic.title || "Unknown", " Optimized", "") || "Untitled"}
          </h3>
          <%= if @comic.author do %>
            <p class={comic_card_classes(:author)}>{@comic.author}</p>
          <% end %>
          <div class={comic_card_classes(:metadata_row)}>
            <span class={comic_card_classes(:metadata_format)}>{@comic.format}</span>
            <%= if @comic.page_count && @comic.page_count > 0 do %>
              <span class={comic_card_classes(:metadata_pages)}>{@comic.page_count} pages</span>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @privdoc """
  **comic_card_container**: Outer wrapper for comic cards with hover effects

  * `group`: enables group-hover states for child elements
  * `cursor-pointer`: shows hand cursor indicating clickability
  """
  def comic_card_classes(:container), do: "group cursor-pointer"

  @privdoc """
  **comic_card_inner**: Main card styling with hover effects

  * `bg-white rounded-lg`: clean white card with soft corners
  * `shadow-sm border border-gray-200`: subtle elevation and border
  * `overflow-hidden`: ensures content doesn't break card boundaries
  * `hover:shadow-md`: slightly stronger shadow on hover for interactivity
  * `transition-shadow`: smooth animation between shadow states
  """
  def comic_card_classes(:inner),
    do: "bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow"

  @privdoc """
  **comic_cover_container**: Container for comic cover image with aspect ratio

  * `aspect-[3/4]`: maintains 3:4 aspect ratio (standard comic book proportions)
  * `bg-gradient-to-br from-blue-50 to-blue-100`: subtle blue gradient fallback
  * `flex items-center justify-center`: centers fallback icon when no image
  """
  def comic_card_classes(:cover_container),
    do: "aspect-[3/4] bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center"

  @privdoc """
  **comic_cover_image**: Styling for the actual comic cover image

  * `w-full h-full`: fills entire container
  * `object-cover`: maintains aspect ratio, crops if needed (like CSS background-size: cover)
  """
  def comic_card_classes(:cover_image), do: "w-full h-full object-cover"

  @privdoc """
  **comic_fallback_icon**: Icon shown when no cover image is available

  * `h-8 w-8`: medium size icon (32px)
  * `text-blue-400`: light blue to match gradient background
  """
  def comic_card_classes(:fallback_icon), do: "h-8 w-8 text-blue-400"

  @privdoc """
  **comic_content_area**: Padding area for text content below cover

  * `p-3`: comfortable padding (12px) around text content
  """
  def comic_card_classes(:content_area), do: "p-3"

  @privdoc """
  **comic_title**: Main title styling with hover effects

  * `font-medium`: slightly bolder than normal text
  * `text-gray-900`: dark gray for good readability
  * `text-sm`: small text size (14px) appropriate for card
  * `line-clamp-2`: truncates to 2 lines with ellipsis if too long
  * `group-hover:text-blue-600`: title turns blue when card is hovered
  * `transition-colors`: smooth color change animation
  """
  def comic_card_classes(:title),
    do: "font-medium text-gray-900 text-sm line-clamp-2 group-hover:text-blue-600 transition-colors"

  @privdoc """
  **comic_author**: Author name styling (secondary information)

  * `text-xs`: extra small text (12px)
  * `text-gray-500`: medium gray (less prominent than title)
  * `mt-1`: small top margin (4px) for spacing
  * `truncate`: single line with ellipsis if too long
  """
  def comic_card_classes(:author), do: "text-xs text-gray-500 mt-1 truncate"

  @privdoc """
  **comic_metadata_row**: Container for format and page count info

  * `flex items-center justify-between`: spreads format and page count to opposite ends
  * `mt-2`: small top margin (8px) for spacing from author
  """
  def comic_card_classes(:metadata_row), do: "flex items-center justify-between mt-2"

  @privdoc """
  **comic_metadata_text**: Styling for format and page count text

  * `text-xs`: extra small text (12px)
  * `text-gray-400`: light gray (tertiary information)
  * `uppercase`: format looks better in caps (CBZ, PDF, etc.)
  """
  def comic_card_classes(:metadata_format), do: "text-xs text-gray-400 uppercase"
  def comic_card_classes(:metadata_pages), do: "text-xs text-gray-400"

  @privdoc """
  **remove_button**: Red X button for removing comics from collections

  * `absolute top-2 right-2`: positioned in top-right corner of card
  * `w-6 h-6`: small circular button (24px)
  * `bg-red-600 text-white`: red background with white X icon
  * `rounded-full`: perfect circle
  * `opacity-0 group-hover:opacity-100`: hidden until card is hovered
  * `hover:bg-red-700`: darker red on direct hover
  * `transition-all`: smooth animation for opacity and color changes
  * `flex items-center justify-center`: centers the X icon
  """
  def comic_card_classes(:remove_button),
    do:
      "absolute top-2 right-2 w-6 h-6 bg-red-600 text-white rounded-full opacity-0 group-hover:opacity-100 hover:bg-red-700 transition-all flex items-center justify-center"

  @privdoc """
  **remove_icon**: X icon inside the remove button

  * `h-4 w-4`: small icon (16px) that fits nicely in 24px button
  """
  def comic_card_classes(:remove_icon), do: "h-4 w-4"
end
