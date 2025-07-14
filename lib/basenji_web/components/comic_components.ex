defmodule BasenjiWeb.ComicComponents do
  @moduledoc false
  use Phoenix.Component

  import BasenjiWeb.CoreComponents

  attr :comic, :any
  def comic_card(assigns) do
    # TODO: load preview on the fly if unavailable
    ~H"""
    <div class="group cursor-pointer">
      <.link navigate={"/comics/#{@comic.id}"} class="block">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
          <div class="aspect-[3/4] bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center">
            <%= if @comic.image_preview do %>
              <img
                src={"/api/comics/#{@comic.id}/preview"}
                alt={@comic.title}
                class="w-full h-full object-cover"
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
    </div>
    """
  end
end
