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
      <.back_to_comics_navigation />

      <%= if @show_reader do %>
        <.comic_reader comic={@comic} current_page={@current_page} />
      <% else %>
        <.comic_details_view comic={@comic} collections={@collections} />
      <% end %>
    </div>
    """
  end

  def back_to_comics_navigation(assigns) do
    ~H"""
    <div>
      <.link navigate={~p"/comics"} class="inline-flex items-center text-gray-600 hover:text-gray-900">
        <.icon name="hero-arrow-left" class="h-5 w-5 mr-2" /> Back to Comics
      </.link>
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true

  def comic_reader(assigns) do
    ~H"""
    <div class="bg-black rounded-lg overflow-hidden">
      <.reader_header comic={@comic} current_page={@current_page} />
      <.reader_page_display comic={@comic} current_page={@current_page} />
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true

  def reader_header(assigns) do
    ~H"""
    <div class="bg-gray-900 px-4 py-3 flex items-center justify-between">
      <div class="flex items-center gap-4 text-white">
        <button phx-click="toggle_reader" class="flex items-center gap-2 hover:text-gray-300">
          <.icon name="hero-x-mark" class="h-5 w-5" /> Close Reader
        </button>
        <span class="text-sm">{@comic.title}</span>
      </div>

      <.reader_navigation current_page={@current_page} page_count={@comic.page_count} />
    </div>
    """
  end

  attr :current_page, :integer, required: true
  attr :page_count, :integer, required: true

  def reader_navigation(assigns) do
    ~H"""
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
          max={@page_count}
          phx-change="change_page"
          name="page"
          class="w-16 px-2 py-1 text-black rounded text-center"
        />
        <span>/ {@page_count}</span>
      </div>

      <button
        phx-click="next_page"
        class="hover:text-gray-300 disabled:opacity-50"
        disabled={@current_page == @page_count}
      >
        <.icon name="hero-chevron-right" class="h-5 w-5" />
      </button>
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true

  def reader_page_display(assigns) do
    ~H"""
    <div class="flex justify-center items-center min-h-[80vh] p-4">
      <img
        src={~p"/api/comics/#{@comic.id}/page/#{@current_page}"}
        alt={"Page #{@current_page}"}
        class="max-w-full max-h-full object-contain"
      />
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :collections, :list, required: true

  def comic_details_view(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      <.comic_cover_and_actions comic={@comic} />
      <.comic_details_and_collections comic={@comic} collections={@collections} />
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_cover_and_actions(assigns) do
    ~H"""
    <div class="space-y-4">
      <.comic_cover comic={@comic} />
      <.comic_action_buttons comic={@comic} />
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_cover(assigns) do
    ~H"""
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
    """
  end

  attr :comic, :any, required: true

  def comic_action_buttons(assigns) do
    ~H"""
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
    """
  end

  attr :comic, :any, required: true
  attr :collections, :list, required: true

  def comic_details_and_collections(assigns) do
    ~H"""
    <div class="lg:col-span-2 space-y-6">
      <.comic_metadata comic={@comic} />
      <.comic_collections_management comic={@comic} collections={@collections} />
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_metadata(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <h1 class="text-3xl font-bold text-gray-900 mb-4">
        {@comic.title || "Untitled Comic"}
      </h1>

      <.comic_metadata_grid comic={@comic} />

      <%= if @comic.description do %>
        <div class="mt-6">
          <h3 class="font-medium text-gray-900 mb-2">Description</h3>
          <p class="text-gray-700 leading-relaxed">{@comic.description}</p>
        </div>
      <% end %>
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_metadata_grid(assigns) do
    ~H"""
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
    """
  end

  attr :comic, :any, required: true
  attr :collections, :list, required: true

  def comic_collections_management(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <h3 class="font-medium text-gray-900 mb-4">Collections</h3>

      <.current_collections comic={@comic} />
      <.add_to_collection_form comic={@comic} collections={@collections} />
    </div>
    """
  end

  attr :comic, :any, required: true

  def current_collections(assigns) do
    ~H"""
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
    """
  end

  attr :comic, :any, required: true
  attr :collections, :list, required: true

  def add_to_collection_form(assigns) do
    ~H"""
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
