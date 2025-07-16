defmodule BasenjiWeb.Comics.ReadLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  import BasenjiWeb.Style.ComicsLiveStyle

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
    {:noreply, change_page(socket, page)}
  end

  def handle_event("handle_keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, :fullscreen, !socket.assigns.fullscreen)}
  end

  def handle_event("handle_keydown", %{"key" => "ArrowLeft"}, socket) do
    {:noreply, change_page(socket, socket.assigns.current_page - 1)}
  end

  def handle_event("handle_keydown", %{"key" => "ArrowRight"}, socket) do
    {:noreply, change_page(socket, socket.assigns.current_page + 1)}
  end

  def handle_event("handle_keydown", %{"key" => " "}, socket) do
    {:noreply, change_page(socket, socket.assigns.current_page + 1)}
  end

  def handle_event("handle_keydown", _params, socket) do
    {:noreply, socket}
  end

  defp change_page(socket, page) when is_bitstring(page) do
    change_page(socket, String.to_integer(page))
  end

  defp change_page(socket, page) when is_number(page) do
    max_page = socket.assigns.comic.page_count

    page_num =
      page
      |> min(max_page)
      |> max(1)

    assign(socket, :current_page, page_num)
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
  attr :fullscreen, :boolean, required: true

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

      <.fullscreen_overlay :if={@fullscreen} comic={@comic} current_page={@current_page} />
    </div>
    """
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true

  defp fullscreen_overlay(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 bg-black flex justify-center items-center"
      phx-window-keydown="handle_keydown"
      phx-click="toggle_fullscreen"
    >
      <.fullscreen_nav_zone :if={@current_page > 1} direction="left" target_page={@current_page - 1} />

      <.fullscreen_nav_zone
        :if={@current_page < @comic.page_count}
        direction="right"
        target_page={@current_page + 1}
      />

      <img
        src={~p"/api/comics/#{@comic.id}/page/#{@current_page}"}
        alt={"Page #{@current_page}"}
        class="max-w-[100vw] max-h-[100vh] object-contain pointer-events-none"
      />
    </div>
    """
  end

  attr :direction, :string, required: true, values: ["left", "right"]
  attr :target_page, :integer, required: true

  defp fullscreen_nav_zone(%{direction: "left"} = assigns) do
    ~H"""
    <div
      class="absolute left-0 top-0 h-full w-1/2 cursor-pointer group"
      phx-click="change_page"
      phx-value-page={@target_page}
    >
      <div class="absolute left-0 top-0 h-full w-32 bg-gradient-to-r from-white from-0% via-white via-30% to-transparent to-100% opacity-0 group-hover:opacity-10 transition-opacity duration-300">
      </div>

      <div class="absolute left-4 top-0 h-full flex items-center">
        <.icon
          name="hero-chevron-left"
          class="h-14 w-14 text-black bg-white bg-opacity-90 rounded-full p-3 opacity-0 group-hover:opacity-95 transition-all duration-300 shadow-2xl hover:scale-110"
        />
      </div>
    </div>
    """
  end

  defp fullscreen_nav_zone(%{direction: "right"} = assigns) do
    ~H"""
    <div
      class="absolute right-0 top-0 h-full w-1/2 cursor-pointer group"
      phx-click="change_page"
      phx-value-page={@target_page}
    >
      <div class="absolute right-0 top-0 h-full w-32 bg-gradient-to-l from-white from-0% via-white via-30% to-transparent to-100% opacity-0 group-hover:opacity-10 transition-opacity duration-300">
      </div>

      <div class="absolute right-4 top-0 h-full flex items-center">
        <.icon
          name="hero-chevron-right"
          class="h-14 w-14 text-black bg-white bg-opacity-90 rounded-full p-3 opacity-0 group-hover:opacity-95 transition-all duration-300 shadow-2xl hover:scale-110"
        />
      </div>
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
