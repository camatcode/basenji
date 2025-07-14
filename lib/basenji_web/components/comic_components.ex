defmodule BasenjiWeb.ComicComponents do
  @moduledoc false
  use BasenjiWeb, :live_component

  import BasenjiWeb.CoreComponents
  import BasenjiWeb.Style.ComicStyle

  attr :comic, :any, required: true, doc: "The comic struct to display"
  attr :show_remove, :boolean, default: false, doc: "Whether to show a remove button"
  attr :class, :string, default: "", doc: "Additional CSS classes for the card container"
  attr :lazy_loading, :boolean, default: true, doc: "Whether to use lazy loading for images"

  def comic_card(assigns) do
    # TODO: load preview on the fly if unavailable
    ~H"""
    <div class={[comic_card_classes(:container), @class]}>
      <.link navigate={~p"/comics/#{@comic.id}"} class="block">
        <div class={comic_card_classes(:inner)}>
          <div class={comic_card_classes(:cover_container)}>
            <%= if @comic.image_preview do %>
              <img
                src={~p"/api/comics/#{@comic.id}/preview"}
                alt={@comic.title}
                class={comic_card_classes(:cover_image)}
                loading={if @lazy_loading, do: "lazy", else: "eager"}
              />
            <% else %>
              <.icon name="hero-book-open" class={comic_card_classes(:fallback_icon)} />
            <% end %>
          </div>

          <div class={comic_card_classes(:content_area)}>
            <h3 class={comic_card_classes(:title)}>
              {@comic.title || "Untitled"}
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
      </.link>
      
    <!-- Remove Button -->
      <%= if @show_remove do %>
        <button
          phx-click="remove_comic"
          phx-value-comic_id={@comic.id}
          onclick="event.stopPropagation()"
          class={comic_card_classes(:remove_button)}
          title="Remove from collection"
        >
          <.icon name="hero-x-mark" class={comic_card_classes(:remove_icon)} />
        </button>
      <% end %>
    </div>
    """
  end
end
