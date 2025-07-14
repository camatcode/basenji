defmodule BasenjiWeb.ComicsLive.Show do
  @moduledoc false
  use BasenjiWeb, :live_view

  alias Basenji.Collections
  alias Basenji.Comics

  def mount(%{"id" => id}, _session, socket) do
    case Comics.get_comic(id, preload: [:member_collections, :optimized_comic, :original_comic]) do
      {:ok, comic} ->
        socket =
          socket
          |> assign(:page_title, comic.title || "Comic")
          |> assign(:comic, comic)
          |> assign(:current_page, 1)
          |> assign(:show_reader, false)
          |> assign(:collections, Collections.list_collections())

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Comic not found")
          |> push_navigate(to: ~p"/comics")

        {:ok, socket}
    end
  end

  def handle_event("toggle_reader", _params, socket) do
    {:noreply, assign(socket, :show_reader, !socket.assigns.show_reader)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page_num = String.to_integer(page)
    max_page = socket.assigns.comic.page_count

    page_num =
      cond do
        page_num < 1 -> 1
        page_num > max_page -> max_page
        true -> page_num
      end

    {:noreply, assign(socket, :current_page, page_num)}
  end

  def handle_event("next_page", _params, socket) do
    current = socket.assigns.current_page
    max_page = socket.assigns.comic.page_count

    new_page = if current < max_page, do: current + 1, else: current
    {:noreply, assign(socket, :current_page, new_page)}
  end

  def handle_event("prev_page", _params, socket) do
    current = socket.assigns.current_page
    new_page = if current > 1, do: current - 1, else: current
    {:noreply, assign(socket, :current_page, new_page)}
  end

  def handle_event("add_to_collection", %{"collection_id" => collection_id}, socket) do
    case Collections.add_to_collection(collection_id, socket.assigns.comic.id) do
      {:ok, _} ->
        # Reload comic to get updated collections
        {:ok, updated_comic} =
          Comics.get_comic(socket.assigns.comic.id, preload: [:member_collections, :optimized_comic, :original_comic])

        socket =
          socket
          |> assign(:comic, updated_comic)
          |> put_flash(:info, "Added to collection successfully")

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to add to collection")
        {:noreply, socket}
    end
  end

  def handle_event("remove_from_collection", %{"collection_id" => collection_id}, socket) do
    case Collections.remove_from_collection(collection_id, socket.assigns.comic.id) do
      {:ok, _} ->
        # Reload comic to get updated collections
        {:ok, updated_comic} =
          Comics.get_comic(socket.assigns.comic.id, preload: [:member_collections, :optimized_comic, :original_comic])

        socket =
          socket
          |> assign(:comic, updated_comic)
          |> put_flash(:info, "Removed from collection successfully")

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to remove from collection")
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-8xl mx-auto space-y-6">
      <!-- Back Button -->
      <div>
        <.link
          navigate={~p"/comics"}
          class="inline-flex items-center text-gray-600 hover:text-gray-900"
        >
          <.icon name="hero-arrow-left" class="h-5 w-5 mr-2" /> Back to Comics
        </.link>
      </div>

      <%= if @show_reader do %>
        <!-- Reader Mode -->
        <div class="bg-black rounded-lg overflow-hidden">
          <!-- Reader Header -->
          <div class="bg-gray-900 px-4 py-3 flex items-center justify-between">
            <div class="flex items-center gap-4 text-white">
              <button phx-click="toggle_reader" class="flex items-center gap-2 hover:text-gray-300">
                <.icon name="hero-x-mark" class="h-5 w-5" /> Close Reader
              </button>
              <span class="text-sm">{@comic.title}</span>
            </div>

            <div class="flex items-center gap-4 text-white text-sm">
              <button
                phx-click="prev_page"
                class="hover:text-gray-300 disabled:opacity-50"
                disabled={@current_page == 1}
              >
                <.icon name="hero-chevron-left" class="h-5 w-5" />
              </button>

              <div class="flex items-center gap-2">
                <input
                  type="number"
                  value={@current_page}
                  min="1"
                  max={@comic.page_count}
                  phx-change="change_page"
                  name="page"
                  class="w-16 px-2 py-1 text-black rounded text-center"
                />
                <span>/ {@comic.page_count}</span>
              </div>

              <button
                phx-click="next_page"
                class="hover:text-gray-300 disabled:opacity-50"
                disabled={@current_page == @comic.page_count}
              >
                <.icon name="hero-chevron-right" class="h-5 w-5" />
              </button>
            </div>
          </div>
          
    <!-- Comic Page -->
          <div class="flex justify-center items-center min-h-[80vh] p-4">
            <img
              src={~p"/api/comics/#{@comic.id}/page/#{@current_page}"}
              alt={"Page #{@current_page}"}
              class="max-w-full max-h-full object-contain"
            />
          </div>
        </div>
      <% else %>
        <!-- Details Mode -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Left Column - Cover and Actions -->
          <div class="space-y-4">
            <!-- Comic Cover -->
            <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
              <div class="aspect-[3/4] bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center">
                <%= if @comic.image_preview do %>
                  <img
                    src={~p"/api/comics/#{@comic.id}/preview"}
                    alt={@comic.title}
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <.icon name="hero-book-open" class="h-16 w-16 text-blue-400" />
                <% end %>
              </div>
            </div>
            
    <!-- Action Buttons -->
            <div class="space-y-2">
              <button
                phx-click="toggle_reader"
                class="w-full bg-blue-600 text-white px-4 py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium"
              >
                <.icon name="hero-book-open" class="h-5 w-5 inline mr-2" /> Read Comic
              </button>

              <%= if @comic.optimized_comic do %>
                <.link
                  navigate={~p"/comics/#{@comic.optimized_comic.id}"}
                  class="w-full bg-green-600 text-white px-4 py-3 rounded-lg hover:bg-green-700 transition-colors font-medium text-center block"
                >
                  <.icon name="hero-bolt" class="h-5 w-5 inline mr-2" /> View Optimized Version
                </.link>
              <% end %>

              <%= if @comic.original_comic do %>
                <.link
                  navigate={~p"/comics/#{@comic.original_comic.id}"}
                  class="w-full bg-gray-600 text-white px-4 py-3 rounded-lg hover:bg-gray-700 transition-colors font-medium text-center block"
                >
                  <.icon name="hero-document" class="h-5 w-5 inline mr-2" /> View Original Version
                </.link>
              <% end %>
            </div>
          </div>
          
    <!-- Right Column - Details -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Title and Basic Info -->
            <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
              <h1 class="text-3xl font-bold text-gray-900 mb-4">
                {@comic.title || "Untitled Comic"}
              </h1>

              <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                <%= if @comic.author do %>
                  <div>
                    <dt class="font-medium text-gray-500">Author</dt>
                    <dd class="text-gray-900">{@comic.author}</dd>
                  </div>
                <% end %>

                <%= if @comic.released_year && @comic.released_year > 0 do %>
                  <div>
                    <dt class="font-medium text-gray-500">Released</dt>
                    <dd class="text-gray-900">{@comic.released_year}</dd>
                  </div>
                <% end %>

                <div>
                  <dt class="font-medium text-gray-500">Format</dt>
                  <dd class="text-gray-900 uppercase">{@comic.format}</dd>
                </div>

                <%= if @comic.page_count && @comic.page_count > 0 do %>
                  <div>
                    <dt class="font-medium text-gray-500">Pages</dt>
                    <dd class="text-gray-900">{@comic.page_count}</dd>
                  </div>
                <% end %>

                <%= if @comic.byte_size && @comic.byte_size > 0 do %>
                  <div>
                    <dt class="font-medium text-gray-500">File Size</dt>
                    <dd class="text-gray-900">{format_bytes(@comic.byte_size)}</dd>
                  </div>
                <% end %>

                <div>
                  <dt class="font-medium text-gray-500">Added</dt>
                  <dd class="text-gray-900">{DateTime.to_date(@comic.inserted_at)}</dd>
                </div>
              </div>

              <%= if @comic.description do %>
                <div class="mt-6">
                  <h3 class="font-medium text-gray-900 mb-2">Description</h3>
                  <p class="text-gray-700 leading-relaxed">{@comic.description}</p>
                </div>
              <% end %>
            </div>
            
    <!-- Collections -->
            <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
              <h3 class="font-medium text-gray-900 mb-4">Collections</h3>

              <%= if length(@comic.member_collections) > 0 do %>
                <div class="flex flex-wrap gap-2 mb-4">
                  <%= for collection <- @comic.member_collections do %>
                    <div class="flex items-center gap-2 bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm">
                      <.link navigate={~p"/collections/#{collection.id}"} class="hover:underline">
                        {collection.title}
                      </.link>
                      <button
                        phx-click="remove_from_collection"
                        phx-value-collection_id={collection.id}
                        class="text-blue-600 hover:text-blue-800"
                      >
                        <.icon name="hero-x-mark" class="h-4 w-4" />
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
              
    <!-- Add to Collection -->
              <%= if length(@collections) > 0 do %>
                <div class="flex gap-2">
                  <select
                    id="collection-select"
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="">Select a collection...</option>
                    <%= for collection <- @collections do %>
                      <%= unless Enum.any?(@comic.member_collections, &(&1.id == collection.id)) do %>
                        <option value={collection.id}>{collection.title}</option>
                      <% end %>
                    <% end %>
                  </select>
                  <button
                    phx-click="add_to_collection"
                    phx-value-collection_id=""
                    onclick="this.setAttribute('phx-value-collection_id', document.getElementById('collection-select').value)"
                    class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    Add
                  </button>
                </div>
              <% else %>
                <p class="text-gray-500 text-sm">
                  No collections available. Create some collections first.
                </p>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "Unknown"
end
