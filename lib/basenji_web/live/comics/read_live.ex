defmodule BasenjiWeb.Comics.ReadLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  alias Basenji.Comics
  alias Basenji.Comics.Comic

  def mount(%{"id" => id}, _session, socket) do
    socket
    |> assign_comic(id)
    |> then(&{:ok, &1, layout: {BasenjiWeb.Layouts, :reader}})
  end

  def handle_params(params, _url, socket) do
    page = params["page"] || "1"

    socket
    |> change_page(page)
    |> then(&{:noreply, &1})
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply,
     socket
     |> change_page(page)
     |> patch_url()
     |> push_event("scroll-to-top", %{})}
  end

  def handle_event("handle_keydown", %{"key" => "ArrowLeft"}, socket) do
    {:noreply,
     socket
     |> change_page(socket.assigns.current_page - 1)
     |> patch_url()
     |> push_event("scroll-to-top", %{})}
  end

  def handle_event("handle_keydown", %{"key" => "ArrowRight"}, socket) do
    {:noreply,
     socket
     |> change_page(socket.assigns.current_page + 1)
     |> patch_url()
     |> push_event("scroll-to-top", %{})}
  end

  def handle_event("handle_keydown", _, socket) do
    {:noreply, socket}
  end

  defp assign_comic(socket, %Comic{} = comic) do
    socket
    |> assign(:page_title, comic.title || "Comic")
    |> assign(:comic, comic)
    |> assign(:current_page, 1)
  end

  defp assign_comic(socket, comic_id) when is_bitstring(comic_id) do
    Comics.get_comic(comic_id)
    |> case do
      {:ok, comic} ->
        assign_comic(socket, comic)

      _ ->
        socket
        |> put_flash(:error, "Comic not found")
        |> push_navigate(to: ~p"/")
    end
  end

  defp patch_url(socket) do
    socket
    |> push_patch(to: "/comics/#{socket.assigns.comic.id}/read?#{socket.assigns.q_string}")
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
    |> update_current_params(%{"page" => "#{page_num}"})
  end

  defp update_current_params(socket, params) do
    current_params = socket.assigns[:current_params] || %{}
    new_current_params = Map.merge(current_params, params)
    q = URI.encode_query(new_current_params)

    socket
    |> assign(:current_params, new_current_params)
    |> assign(:q_string, q)
  end

  attr :comic, :any, required: true
  attr :current_page, :integer, required: true

  def render(assigns) do
    ~H"""
    <div phx-window-keydown="handle_keydown" phx-hook="ScrollToTop" id="reader-page-display">
      <div class="relative portrait-container">
        <div
          phx-hook="ResponsiveImageHook"
          data-comic-id={@comic.id}
          data-current-page={@current_page}
          id={"responsive-image-#{@current_page}"}
        >
          <img
            src={~p"/api/comics/#{@comic.id}/page/#{@current_page}"}
            alt={"Page #{@current_page}"}
            class="landscape-image w-full h-auto object-contain"
          />
        </div>
        <.previous_page_nav :if={@current_page > 1} current_page={@current_page} />
        <.next_page_nav :if={@current_page < @comic.page_count} current_page={@current_page} />
      </div>
    </div>
    """
  end

  attr :current_page, :integer, required: true

  def previous_page_nav(assigns) do
    ~H"""
    <div
      class="previous_page_nav absolute left-0 top-0 h-full w-1/6 cursor-pointer group"
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
      class="next_page_nav absolute right-0 top-0 h-full w-1/6 cursor-pointer group"
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
