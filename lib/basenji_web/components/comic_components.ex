defmodule BasenjiWeb.ComicComponents do
  @moduledoc false
  use BasenjiWeb, :live_component

  import BasenjiWeb.CoreComponents

  attr :comic, :any, required: true, doc: "The comic struct to display"
  attr :show_remove, :boolean, default: false, doc: "Whether to show a remove button"
  attr :class, :string, default: "", doc: "Additional CSS classes for the card container"
  attr :lazy_loading, :boolean, default: true, doc: "Whether to use lazy loading for images"

  def comic_card(assigns) do
    # TODO: load preview on the fly if unavailable
    ~H"""
    <div class={["group cursor-pointer relative", @class]}>
      <.link navigate={~p"/comics/#{@comic.id}"} class="block">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
          <div class="aspect-[3/4] bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center">
            <%= if @comic.image_preview do %>
              <img
                src={~p"/api/comics/#{@comic.id}/preview"}
                alt={@comic.title}
                class="w-full h-full object-cover"
                loading={if @lazy_loading, do: "lazy", else: "eager"}
              />
            <% else %>
              <.icon name="hero-book-open" class="h-8 w-8 text-blue-400" />
            <% end %>
          </div>

          <div class="p-3">
            <h3 class="font-medium text-gray-900 text-sm line-clamp-2 group-hover:text-blue-600 transition-colors">
              {@comic.title || "Untitled"}
            </h3>
            <%= if @comic.author do %>
              <p class="text-xs text-gray-500 mt-1 truncate">{@comic.author}</p>
            <% end %>
            <div class="flex items-center justify-between mt-2">
              <span class="text-xs text-gray-400 uppercase">{@comic.format}</span>
              <%= if @comic.page_count && @comic.page_count > 0 do %>
                <span class="text-xs text-gray-400">{@comic.page_count} pages</span>
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
          class="absolute top-2 right-2 w-6 h-6 bg-red-600 text-white rounded-full opacity-0 group-hover:opacity-100 hover:bg-red-700 transition-all flex items-center justify-center"
          title="Remove from collection"
        >
          <.icon name="hero-x-mark" class="h-4 w-4" />
        </button>
      <% end %>
    </div>
    """
  end
end
