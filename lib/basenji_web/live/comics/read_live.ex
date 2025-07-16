defmodule BasenjiWeb.Comics.ReadLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.Style.ComicsLiveStyle
  import BasenjiWeb.Style.SharedStyle

  alias Basenji.Collections
  alias Basenji.Comic
  alias Basenji.Comics

  def mount(%{"id" => id}, _session, socket) do
    socket
    |> assign_comic(id)
  end

  defp assign_comic(socket, %Comic{} = comic) do
    socket
    |> assign(:page_title, comic.title || "Comic")
    |> assign(:comic, comic)
    |> assign(:current_page, 1)
    |> assign(:fullscreen, true)
    |> then(&{:ok, &1})
  end

  defp assign_comic(socket, comic_id) when is_bitstring(comic_id) do
    Comics.get_comic(comic_id, preload: [:member_collections, :optimized_comic, :original_comic])
    |> case do
      {:ok, comic} ->
        assign_comic(socket, comic)

      _ ->
        socket
        |> put_flash(:error, "Comic not found")
        |> push_navigate(to: ~p"/")
    end
  end

  def handle_event("toggle_fullscreen", _params, socket) do
    {:noreply, assign(socket, :fullscreen, !socket.assigns.fullscreen)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    max_page = socket.assigns.comic.page_count

    page_num =
      String.to_integer(page)
      |> min(max_page)
      |> max(1)

    {:noreply, assign(socket, :current_page, page_num)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-8xl mx-auto space-y-6">
      <.comic_reader comic={@comic} current_page={@current_page} fullscreen={@fullscreen} />
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true

  def comic_reader(assigns) do
    ~H"""
    <div class="bg-black rounded-lg overflow-hidden">
      <.reader_header comic={@comic} current_page={@current_page} />
      <.reader_page_display comic={@comic} current_page={@current_page} fullscreen={@fullscreen} />
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true

  def reader_header(assigns) do
    ~H"""
    <div class="">
      <.reader_navigation current_page={@current_page} page_count={@comic.page_count} />
    </div>
    """
  end

  attr :current_page, :integer, required: true
  attr :page_count, :integer, required: true

  def reader_navigation(assigns) do
    ~H"""
    <div class={["place-content-center", comics_live_classes(:reader_navigation)]}>
      <div class={comics_live_classes(:reader_page_input_container)}>
        <span>{@current_page} / {@page_count}</span>
      </div>
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true
  attr :fullscreen, :boolean, required: true

  def reader_page_display(assigns) do
    ~H"""
    <div class={comics_live_classes(:reader_page_display)}>
      <div class="relative">
        <img
          src={~p"/api/comics/#{@comic.id}/page/#{@current_page}"}
          alt={"Page #{@current_page}"}
          class={comics_live_classes(:reader_page_image)}
          phx-click="toggle_fullscreen"
        />
        <.previous_page_nav :if={@current_page > 1} current_page={@current_page} />
        <.next_page_nav :if={@current_page < @comic.page_count} current_page={@current_page} />
      </div>
      
    <!-- Fullscreen overlay with adaptive navigation -->
      <%= if @fullscreen do %>
        <div
          class="fixed inset-0 z-50 bg-black flex justify-center items-center"
          phx-click="toggle_fullscreen"
        >
          <!-- Left navigation zone - covers entire left half of screen -->
          <%= if @current_page > 1 do %>
            <div
              class="absolute left-0 top-0 h-full w-1/2 cursor-pointer group"
              phx-click="change_page"
              phx-value-page={@current_page - 1}
            >
              <!-- Gradient at far left edge -->
              <div class="absolute left-0 top-0 h-full w-32 bg-gradient-to-r from-black from-0% via-black via-30% to-transparent to-100% opacity-0 group-hover:opacity-15 transition-opacity duration-300">
              </div>
              
    <!-- Chevron at far left edge -->
              <div class="absolute left-4 top-0 h-full flex items-center">
                <.icon
                  name="hero-chevron-left"
                  class="h-14 w-14 text-white bg-gray-800 bg-opacity-90 rounded-full p-3 opacity-0 group-hover:opacity-95 transition-all duration-300 shadow-2xl backdrop-blur-sm hover:scale-110 mix-blend-difference"
                />
              </div>
            </div>
          <% end %>
          
    <!-- Right navigation zone - covers entire right half of screen -->
          <%= if @current_page < @comic.page_count do %>
            <div
              class="absolute right-0 top-0 h-full w-1/2 cursor-pointer group"
              phx-click="change_page"
              phx-value-page={@current_page + 1}
            >
              <!-- Gradient at far right edge -->
              <div class="absolute right-0 top-0 h-full w-32 bg-gradient-to-l from-black from-0% via-black via-30% to-transparent to-100% opacity-0 group-hover:opacity-15 transition-opacity duration-300">
              </div>
              
    <!-- Chevron at far right edge -->
              <div class="absolute right-4 top-0 h-full flex items-center">
                <.icon
                  name="hero-chevron-right"
                  class="h-14 w-14 text-white bg-gray-800 bg-opacity-90 rounded-full p-3 opacity-0 group-hover:opacity-95 transition-all duration-300 shadow-2xl backdrop-blur-sm hover:scale-110 mix-blend-difference"
                />
              </div>
            </div>
          <% end %>
          
    <!-- Comic image in center -->
          <img
            src={~p"/api/comics/#{@comic.id}/page/#{@current_page}"}
            alt={"Page #{@current_page}"}
            class="max-w-[100vw] max-h-[100vh] object-contain pointer-events-none"
          />
        </div>
      <% end %>
    </div>
    """
  end

  attr :current_page, :integer, required: true

  def previous_page_nav(assigns) do
    ~H"""
    <div
      class="absolute left-0 top-0 h-full w-1/6 cursor-pointer group"
      phx-click="change_page"
      phx-value-page={@current_page - 1}
    >
      <div class="h-full w-full bg-gradient-to-r from-black from-0% via-black via-10% to-transparent to-70% opacity-0 group-hover:opacity-15 transition-opacity duration-300">
      </div>

      <div class="absolute inset-0 flex items-center justify-start pl-3">
        <.icon
          name="hero-chevron-left"
          class="h-14 w-14 text-white bg-black bg-opacity-75 rounded-full p-3 opacity-0 group-hover:opacity-95 transition-all duration-300 shadow-2xl backdrop-blur-sm hover:scale-110"
        />
      </div>
    </div>
    """
  end

  attr :current_page, :integer, required: true

  def next_page_nav(assigns) do
    ~H"""
    <div
      class="absolute right-0 top-0 h-full w-1/6 cursor-pointer group"
      phx-click="change_page"
      phx-value-page={@current_page + 1}
    >
      <div class="h-full w-full bg-gradient-to-l from-black from-0% via-black via-10% to-transparent to-70% opacity-0 group-hover:opacity-15 transition-opacity duration-300">
      </div>

      <div class="absolute inset-0 flex items-center justify-end pr-3">
        <.icon
          name="hero-chevron-right"
          class="h-14 w-14 text-white bg-black bg-opacity-75 rounded-full p-3 opacity-0 group-hover:opacity-95 transition-all duration-300 shadow-2xl backdrop-blur-sm hover:scale-110"
        />
      </div>
    </div>
    """
  end
end
