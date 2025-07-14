defmodule BasenjiWeb.CollectionComponents do
  @moduledoc false
  use BasenjiWeb, :live_component

  import BasenjiWeb.CoreComponents

  attr :collection, :any, required: true, doc: "The collection struct to display"
  attr :class, :string, default: "", doc: "Additional CSS classes for the card container"
  attr :show_comic_count, :boolean, default: false, doc: "Whether to show the number of comics in the collection"

  def collection_card(assigns) do
    ~H"""
    <div class={["group cursor-pointer", @class]}>
      <.link navigate={~p"/collections/#{@collection.id}"} class="block">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow h-full">
          <div class="flex items-start gap-4">
            <div class="flex-shrink-0">
              <div class="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
                <.icon name="hero-folder" class="h-7 w-7 text-yellow-600" />
              </div>
            </div>
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold text-gray-900 group-hover:text-blue-600 transition-colors mb-2">
                {@collection.title}
              </h3>
              <%= if @collection.description do %>
                <p class="text-sm text-gray-600 mb-3 line-clamp-3">
                  {@collection.description}
                </p>
              <% end %>

              <div class="flex items-center justify-between text-xs text-gray-500">
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
