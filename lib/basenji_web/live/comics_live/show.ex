defmodule BasenjiWeb.ComicsLive.Show do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.Style.ComicsLiveStyle
  import BasenjiWeb.Style.SharedStyle

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
      <.link navigate={~p"/comics"} class={navigation_classes(:back_link)}>
        <.icon name="hero-arrow-left" class={navigation_classes(:back_icon)} /> Back to Comics
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
    <div class={comics_live_classes(:reader_navigation)}>
      <button
        phx-click="prev_page"
        class={comics_live_classes(:reader_nav_button)}
        disabled={@current_page == 1}
      >
        <.icon name="hero-chevron-left" class={comics_live_classes(:reader_nav_icon)} />
      </button>

      <div class={comics_live_classes(:reader_page_input_container)}>
        <input
          type="number"
          value={@current_page}
          min="1"
          max={@page_count}
          phx-change="change_page"
          name="page"
          class={comics_live_classes(:reader_page_input)}
        />
        <span>/ {@page_count}</span>
      </div>

      <button
        phx-click="next_page"
        class={comics_live_classes(:reader_nav_button)}
        disabled={@current_page == @page_count}
      >
        <.icon name="hero-chevron-right" class={comics_live_classes(:reader_nav_icon)} />
      </button>
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true

  def reader_page_display(assigns) do
    ~H"""
    <div class={comics_live_classes(:reader_page_display)}>
      <img
        src={~p"/api/comics/#{@comic.id}/page/#{@current_page}"}
        alt={"Page #{@current_page}"}
        class={comics_live_classes(:reader_page_image)}
      />
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :collections, :list, required: true

  def comic_details_view(assigns) do
    ~H"""
    <div class={comics_live_classes(:details_grid)}>
      <.comic_cover_and_actions comic={@comic} />
      <.comic_details_and_collections comic={@comic} collections={@collections} />
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_cover_and_actions(assigns) do
    ~H"""
    <div class={comics_live_classes(:cover_section)}>
      <.comic_cover comic={@comic} />
      <.comic_action_buttons comic={@comic} />
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_cover(assigns) do
    ~H"""
    <div class={comics_live_classes(:cover_card)}>
      <div class={comics_live_classes(:cover_image_container)}>
        <%= if @comic.image_preview do %>
          <img
            src={~p"/api/comics/#{@comic.id}/preview"}
            alt={@comic.title}
            class={comics_live_classes(:cover_image)}
          />
        <% else %>
          <.icon name="hero-book-open" class={comics_live_classes(:cover_fallback_icon)} />
        <% end %>
      </div>
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_action_buttons(assigns) do
    ~H"""
    <div class={comics_live_classes(:action_buttons_container)}>
      <button phx-click="toggle_reader" class={comics_live_classes(:primary_action_button)}>
        <.icon name="hero-book-open" class={comics_live_classes(:action_button_icon)} /> Read Comic
      </button>

      <%= if @comic.optimized_comic do %>
        <.link
          navigate={~p"/comics/#{@comic.optimized_comic.id}"}
          class={comics_live_classes(:secondary_action_button_green)}
        >
          <.icon name="hero-bolt" class={comics_live_classes(:action_button_icon)} />
          View Optimized Version
        </.link>
      <% end %>

      <%= if @comic.original_comic do %>
        <.link
          navigate={~p"/comics/#{@comic.original_comic.id}"}
          class={comics_live_classes(:secondary_action_button_gray)}
        >
          <.icon name="hero-document" class={comics_live_classes(:action_button_icon)} />
          View Original Version
        </.link>
      <% end %>
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :collections, :list, required: true

  def comic_details_and_collections(assigns) do
    ~H"""
    <div class={comics_live_classes(:details_section)}>
      <.comic_metadata comic={@comic} />
      <.comic_collections_management comic={@comic} collections={@collections} />
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_metadata(assigns) do
    ~H"""
    <div class={comics_live_classes(:metadata_card)}>
      <h1 class={comics_live_classes(:comic_title)}>
        {@comic.title || "Untitled Comic"}
      </h1>

      <.comic_metadata_grid comic={@comic} />

      <%= if @comic.description do %>
        <div class={comics_live_classes(:description_section)}>
          <h3 class={comics_live_classes(:description_heading)}>Description</h3>
          <p class={comics_live_classes(:description_text)}>{@comic.description}</p>
        </div>
      <% end %>
    </div>
    """
  end

  attr :comic, :any, required: true

  def comic_metadata_grid(assigns) do
    ~H"""
    <div class={comics_live_classes(:metadata_grid)}>
      <%= if @comic.author do %>
        <div>
          <dt class={comics_live_classes(:metadata_label)}>Author</dt>
          <dd class={comics_live_classes(:metadata_value)}>{@comic.author}</dd>
        </div>
      <% end %>

      <%= if @comic.released_year && @comic.released_year > 0 do %>
        <div>
          <dt class={comics_live_classes(:metadata_label)}>Released</dt>
          <dd class={comics_live_classes(:metadata_value)}>{@comic.released_year}</dd>
        </div>
      <% end %>

      <div>
        <dt class={comics_live_classes(:metadata_label)}>Format</dt>
        <dd class={comics_live_classes(:metadata_value_uppercase)}>{@comic.format}</dd>
      </div>

      <%= if @comic.page_count && @comic.page_count > 0 do %>
        <div>
          <dt class={comics_live_classes(:metadata_label)}>Pages</dt>
          <dd class={comics_live_classes(:metadata_value)}>{@comic.page_count}</dd>
        </div>
      <% end %>

      <%= if @comic.byte_size && @comic.byte_size > 0 do %>
        <div>
          <dt class={comics_live_classes(:metadata_label)}>File Size</dt>
          <dd class={comics_live_classes(:metadata_value)}>{format_bytes(@comic.byte_size)}</dd>
        </div>
      <% end %>

      <div>
        <dt class={comics_live_classes(:metadata_label)}>Added</dt>
        <dd class={comics_live_classes(:metadata_value)}>{DateTime.to_date(@comic.inserted_at)}</dd>
      </div>
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :collections, :list, required: true

  def comic_collections_management(assigns) do
    ~H"""
    <div class={comics_live_classes(:metadata_card)}>
      <h3 class={comics_live_classes(:collections_section_heading)}>Collections</h3>

      <.current_collections comic={@comic} />
      <.add_to_collection_form comic={@comic} collections={@collections} />
    </div>
    """
  end

  attr :comic, :any, required: true

  def current_collections(assigns) do
    ~H"""
    <%= if length(@comic.member_collections) > 0 do %>
      <div class={comics_live_classes(:collection_tags_container)}>
        <%= for collection <- @comic.member_collections do %>
          <div class={comics_live_classes(:collection_tag)}>
            <.link
              navigate={~p"/collections/#{collection.id}"}
              class={comics_live_classes(:collection_tag_link)}
            >
              {collection.title}
            </.link>
            <button
              phx-click="remove_from_collection"
              phx-value-collection_id={collection.id}
              class={comics_live_classes(:collection_tag_remove)}
            >
              <.icon name="hero-x-mark" class={comics_live_classes(:collection_tag_icon)} />
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
      <div class={comics_live_classes(:add_collection_form)}>
        <select id="collection-select" class={comics_live_classes(:add_collection_select)}>
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
          class={comics_live_classes(:add_collection_button)}
        >
          Add
        </button>
      </div>
    <% else %>
      <p class={comics_live_classes(:no_collections_message)}>
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
