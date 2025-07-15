defmodule BasenjiWeb.HomeLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.CollectionComponents
  import BasenjiWeb.ComicComponents
  import BasenjiWeb.SharedComponents
  import BasenjiWeb.Style.ComicStyle
  import BasenjiWeb.Style.SharedStyle

  alias Basenji.Collections
  alias Basenji.Comics

  def mount(_params, _session, socket) do
    socket
    |> assign_current_collection(nil)
    |> assign_content()
    |> then(&{:ok, &1})
  end

  def handle_event("navigate_to_collection", %{"collection_id" => collection_id}, socket) do
    socket =
      socket
      |> assign_current_collection(collection_id)
      |> assign_content()

    {:noreply, socket}
  end

  def handle_event("navigate_up", _params, socket) do
    # Get parent of current collection, or go to root if current is at root level
    parent_id =
      case socket.assigns.current_collection do
        nil -> nil
        collection -> collection.parent_id
      end

    socket =
      socket
      |> assign_current_collection(parent_id)
      |> assign_content()

    {:noreply, socket}
  end

  defp assign_current_collection(socket, nil) do
    socket
    |> assign(:current_collection, nil)
    |> assign(:current_collection_id, nil)
  end

  defp assign_current_collection(socket, collection_id) when is_binary(collection_id) do
    case Collections.get_collection(collection_id) do
      {:ok, collection} ->
        socket
        |> assign(:current_collection, collection)
        |> assign(:current_collection_id, collection_id)

      {:error, :not_found} ->
        # If collection not found, go back to root
        assign_current_collection(socket, nil)
    end
  end

  defp assign_content(socket) do
    current_collection_id = socket.assigns.current_collection_id

    # Get collections in current context
    collections =
      if current_collection_id do
        Collections.list_collections(parent_id: current_collection_id)
      else
        Collections.list_collections(parent_id: :none)
      end

    # Get comics in current context
    comics =
      if current_collection_id do
        # Get comics in this collection - we'll need to implement this
        get_comics_in_collection(current_collection_id)
      else
        # For now, show all comics at root level
        Comics.list_comics()
      end

    socket
    |> assign(:collections, collections)
    |> assign(:comics, comics)
  end

  # Placeholder - we'll need to implement this properly
  defp get_comics_in_collection(_collection_id) do
    # This would need to query the collection_comics join table
    # For now, return empty list
    []
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto space-y-6">
      <.page_header current_collection={@current_collection} />
      <.content_grid
        collections={@collections}
        comics={@comics}
        current_collection={@current_collection}
      />
    </div>
    """
  end

  attr :current_collection, :any, default: nil

  def page_header(assigns) do
    ~H"""
    <div class={page_classes(:header_layout)}>
      <div>
        <h1 class={page_classes(:title)}>
          <%= if @current_collection do %>
            {@current_collection.title}
          <% else %>
            Library
          <% end %>
        </h1>
        <p class={page_classes(:subtitle)}>
          <%= if @current_collection do %>
            Collection
          <% else %>
            Browse your collections and comics
          <% end %>
        </p>
      </div>
    </div>
    """
  end

  attr :collections, :list, required: true
  attr :comics, :list, required: true
  attr :current_collection, :any, default: nil

  def content_grid(assigns) do
    ~H"""
    <div class={grid_classes(:collections_standard)}>
      <!-- Up navigation if not at root -->
      <%= if @current_collection do %>
        <.up_card />
      <% end %>
      
    <!-- Collections first -->
      <%= for collection <- @collections do %>
        <div phx-click="navigate_to_collection" phx-value-collection_id={collection.id}>
          <.collection_card collection={collection} />
        </div>
      <% end %>
      
    <!-- Comics second -->
      <%= for comic <- @comics do %>
        <.comic_card comic={comic} />
      <% end %>
    </div>
    """
  end

  def up_card(assigns) do
    ~H"""
    <div class={[comic_card_classes(:container), "cursor-pointer"]} phx-click="navigate_up">
      <div class="block">
        <div class={comic_card_classes(:inner)}>
          <div class={comic_card_classes(:cover_container)}>
            <.icon name="hero-arrow-up" class={comic_card_classes(:fallback_icon)} />
          </div>
          <div class={comic_card_classes(:content_area)}>
            <h3 class={comic_card_classes(:title)}>
              ..
            </h3>
            <div class={comic_card_classes(:metadata_row)}>
              <small class={comic_card_classes(:metadata_format)}>Up</small>
              <small class={comic_card_classes(:metadata_pages)}></small>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper for pagination - since we're not using URL-based pagination
  defp build_page_path(%{page: page}), do: "#page-#{page}"
end
