defmodule BasenjiWeb.CollectionComponents do
  @moduledoc false
  use BasenjiWeb, :live_component

  import BasenjiWeb.Style.ComicStyle

  attr :collection, :any, required: true, doc: "The collection struct to display"
  attr :class, :string, default: "", doc: "Additional CSS classes for the card container"

  def collection_card(assigns) do
    ~H"""
    <div class={[comic_card_classes(:container), @class]}>
      <div class="block">
        <div class={comic_card_classes(:inner)}>
          <div class={comic_card_classes(:cover_container)}>
            <.icon name="hero-folder" class={comic_card_classes(:fallback_icon)} />
          </div>

          <div class={comic_card_classes(:content_area)}>
            <h3 class={comic_card_classes(:title)}>
              {@collection.title}
            </h3>

            <div class={comic_card_classes(:metadata_row)}>
              <small class={comic_card_classes(:metadata_format)}>Collection</small>
              <small class={comic_card_classes(:metadata_pages)}>
                {DateTime.to_date(@collection.inserted_at)}
              </small>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
