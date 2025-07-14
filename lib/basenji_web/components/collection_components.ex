defmodule BasenjiWeb.CollectionComponents do
  @moduledoc false
  use BasenjiWeb, :live_component

  import BasenjiWeb.CoreComponents
  import BasenjiWeb.Style.CollectionStyle

  attr :collection, :any, required: true, doc: "The collection struct to display"
  attr :class, :string, default: "", doc: "Additional CSS classes for the card container"
  attr :show_comic_count, :boolean, default: false, doc: "Whether to show the number of comics in the collection"

  def collection_card(assigns) do
    ~H"""
    <div class={[collection_card_classes(:container), @class]}>
      <.link navigate={~p"/collections/#{@collection.id}"} class="block">
        <div class={collection_card_classes(:inner)}>
          <div class={collection_card_classes(:content_layout)}>
            <div class={collection_card_classes(:icon_container)}>
              <div class={collection_card_classes(:icon_background)}>
                <.icon name="hero-folder" class={collection_card_classes(:folder_icon)} />
              </div>
            </div>
            <div class={collection_card_classes(:text_container)}>
              <h3 class={collection_card_classes(:title)}>
                {@collection.title}
              </h3>
              <%= if @collection.description do %>
                <p class={collection_card_classes(:description)}>
                  {@collection.description}
                </p>
              <% end %>

              <div class={collection_card_classes(:metadata_row)}>
                <%= if @show_comic_count and @collection.comics do %>
                  <span>{length(@collection.comics)} comics</span>
                <% else %>
                  <span>Collection</span>
                <% end %>
                <span>{DateTime.to_date(@collection.inserted_at)}</span>
              </div>
            </div>
          </div>
        </div>
      </.link>
    </div>
    """
  end
end
