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
      <.comic_reader comic={@comic} current_page={@current_page} />
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
      <button
        phx-click="change_page"
        phx-value-page={@current_page + 1}
        class={comics_live_classes(:reader_nav_button)}
        disabled={@current_page == 1}
      >
        <.icon name="hero-chevron-left" class={comics_live_classes(:reader_nav_icon)} />
      </button>

      <div class={comics_live_classes(:reader_page_input_container)}>
        <span>{@current_page} / {@page_count}</span>
      </div>

      <button
        phx-click="change_page"
        phx-value-page={@current_page + 1}
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
end
