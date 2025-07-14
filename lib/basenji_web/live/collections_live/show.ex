defmodule BasenjiWeb.CollectionsLive.Show do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.ComicComponents
  import BasenjiWeb.Live.Style.CollectionsStyle
  import BasenjiWeb.SharedComponents
  import BasenjiWeb.Style.SharedStyle

  alias Basenji.Collections

  @per_page 24

  def mount(%{"id" => id}, _session, socket) do
    case Collections.get_collection(id, preload: [:comics, :parent]) do
      {:ok, collection} ->
        socket =
          socket
          |> assign(:page_title, collection.title)
          |> assign(:collection, collection)
          |> assign(:current_page, 1)
          |> assign(:sort_by, "title")
          |> assign(:search_query, "")
          |> load_comics()

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Collection not found")
          |> push_navigate(to: ~p"/collections")

        {:ok, socket}
    end
  end

  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || ""
    sort = params["sort"] || "title"

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:search_query, search)
      |> assign(:sort_by, sort)
      |> load_comics()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => search}, socket) do
    socket = push_patch(socket, to: collection_path(socket.assigns.collection.id, %{search: search, page: 1}))
    {:noreply, socket}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    socket =
      push_patch(socket,
        to:
          collection_path(socket.assigns.collection.id, %{
            search: socket.assigns.search_query,
            sort: sort,
            page: 1
          })
      )

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket = push_patch(socket, to: collection_path(socket.assigns.collection.id, %{}))
    {:noreply, socket}
  end

  def handle_event("remove_comic", %{"comic_id" => comic_id}, socket) do
    case Collections.remove_from_collection(socket.assigns.collection.id, comic_id) do
      {:ok, _} ->
        # Reload collection to get updated comics
        {:ok, updated_collection} =
          Collections.get_collection(socket.assigns.collection.id, preload: [:comics, :parent])

        socket =
          socket
          |> assign(:collection, updated_collection)
          |> load_comics()
          |> put_flash(:info, "Comic removed from collection")

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to remove comic")
        {:noreply, socket}
    end
  end

  defp load_comics(socket) do
    %{
      collection: collection,
      search_query: search,
      sort_by: sort,
      current_page: page
    } = socket.assigns

    # Get all comics in collection
    all_comics = collection.comics

    # Apply search filter if provided
    filtered_comics =
      if search == "" do
        all_comics
      else
        search_term = String.downcase(search)

        Enum.filter(all_comics, fn comic ->
          String.contains?(String.downcase(comic.title || ""), search_term) or
            String.contains?(String.downcase(comic.author || ""), search_term) or
            String.contains?(String.downcase(comic.description || ""), search_term)
        end)
      end

    # Apply sorting
    sorted_comics =
      case sort do
        "title" -> Enum.sort_by(filtered_comics, & &1.title)
        "author" -> Enum.sort_by(filtered_comics, & &1.author)
        "inserted_at" -> Enum.sort_by(filtered_comics, & &1.inserted_at, {:desc, DateTime})
        "released_year" -> Enum.sort_by(filtered_comics, & &1.released_year)
        _ -> filtered_comics
      end

    # Apply pagination
    total_comics = length(sorted_comics)
    total_pages = ceil(total_comics / @per_page)
    start_index = (page - 1) * @per_page
    comics = Enum.slice(sorted_comics, start_index, @per_page)

    socket
    |> assign(:comics, comics)
    |> assign(:total_comics, total_comics)
    |> assign(:total_pages, total_pages)
  end

  defp collection_path(collection_id, params) do
    query_params =
      params
      |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
      |> Map.new()

    if Enum.empty?(query_params) do
      ~p"/collections/#{collection_id}"
    else
      ~p"/collections/#{collection_id}?#{query_params}"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.back_to_collections />

      <.collection_header collection={@collection} total_comics={@total_comics} />

      <.search_filter_bar
        search_query={@search_query}
        search_placeholder="Search comics in this collection..."
        sort_options={[
          {"title", "Sort by Title"},
          {"author", "Sort by Author"},
          {"inserted_at", "Sort by Date Added"},
          {"released_year", "Sort by Release Year"}
        ]}
        sort_value={@sort_by}
        show_clear={@search_query != ""}
        clear_event="clear_search"
      />

      <.collection_comics_content
        comics={@comics}
        current_page={@current_page}
        total_pages={@total_pages}
        path_function={fn params -> collection_path(@collection.id, params) end}
        params={
          %{
            search: @search_query,
            sort: @sort_by
          }
        }
        search_query={@search_query}
      />
    </div>
    """
  end

  def back_to_collections(assigns) do
    ~H"""
    <div>
      <.link navigate={~p"/collections"} class={navigation_classes(:back_link)}>
        <.icon name="hero-arrow-left" class={navigation_classes(:back_icon)} /> Back to Collections
      </.link>
    </div>
    """
  end

  attr :collection, :map, required: true
  attr :total_comics, :integer, required: true

  def collection_header(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div class="flex items-start gap-4">
        <div class="w-16 h-16 bg-yellow-100 rounded-lg flex items-center justify-center flex-shrink-0">
          <.icon name="hero-folder" class="h-10 w-10 text-yellow-600" />
        </div>
        <div class="flex-1">
          <h1 class="text-3xl font-bold text-gray-900 mb-2">
            {@collection.title}
          </h1>
          <%= if @collection.description do %>
            <p class="text-gray-600 mb-4 leading-relaxed">
              {@collection.description}
            </p>
          <% end %>
          <div class="flex items-center gap-4 text-sm text-gray-500">
            <span>{@total_comics} comics</span>
            <span>Created {DateTime.to_date(@collection.inserted_at)}</span>
            <%= if @collection.parent do %>
              <span>
                Parent:
                <.link
                  navigate={~p"/collections/#{@collection.parent.id}"}
                  class="text-blue-600 hover:text-blue-700"
                >
                  {@collection.parent.title}
                </.link>
              </span>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :comics, :list, required: true
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :path_function, :any, required: true
  attr :params, :map, required: true
  attr :search_query, :string, required: true

  def collection_comics_content(assigns) do
    ~H"""
    <%= if length(@comics) > 0 do %>
      <.collection_comics_grid comics={@comics} />
      <.pagination
        current_page={@current_page}
        total_pages={@total_pages}
        path_function={@path_function}
        params={@params}
      />
    <% else %>
      <.collection_empty_state search_query={@search_query} />
    <% end %>
    """
  end

  attr :comics, :list, required: true

  def collection_comics_grid(assigns) do
    ~H"""
    <div class={collections_live_classes(:comics_grid)}>
      <%= for comic <- @comics do %>
        <.comic_card comic={comic} show_remove={true} />
      <% end %>
    </div>
    """
  end

  attr :search_query, :string, required: true

  def collection_empty_state(assigns) do
    ~H"""
    <%= if @search_query != "" do %>
      <.empty_state
        icon="hero-book-open"
        title="No comics found"
        description="No comics in this collection match your search."
        show_action={true}
        action_text="Clear search"
        action_event="clear_search"
      />
    <% else %>
      <.empty_state
        icon="hero-book-open"
        title="Empty collection"
        description="This collection doesn't have any comics yet. Add some comics to get started!"
      />
    <% end %>
    """
  end
end
