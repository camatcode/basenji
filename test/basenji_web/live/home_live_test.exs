defmodule BasenjiWeb.HomeLiveTest do
  use BasenjiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Basenji.Comics
  alias BasenjiWeb.HomeLive

  @moduletag :capture_log

  doctest HomeLive

  test "load home page", %{conn: conn} do
    assert {:ok, lv, _html} = live(conn, ~p"/")

    lv
    |> form("form", search_form: %{search_query: "", format_filter: "cbz"})
    |> render_submit()

    html = render(lv)

    assert html =~ "No comics found"

    _inserted_comics = insert_list(12, :comic)

    comics = Comics.list_comics()

    assert {:ok, lv, _html} = live(conn, ~p"/")

    html = render_async(lv)

    Enum.each(comics, fn comic ->
      assert html =~ comic.id
      assert html =~ comic.title
    end)
  end

  test "verify pagination", %{conn: conn} do
    _inserted_comics = insert_list(8 * 24, :comic)

    [chunk_1 | other_chunks] =
      Comics.list_comics(order_by: :title)
      |> Enum.chunk_every(24)

    assert {:ok, lv, html} = live(conn, ~p"/")

    Enum.each(chunk_1, fn comic ->
      assert html =~ comic.id
      assert html =~ comic.title
    end)

    assert has_element?(lv, "#top_pagination")
    assert has_element?(lv, "#bottom_pagination")

    Enum.with_index(other_chunks, 2)
    |> Enum.each(fn {chunk, page_num} ->
      next_button = element(lv, "#top_pagination button", "Next")
      render_click(next_button)
      updated_html = render(lv)

      Enum.each(chunk, fn comic ->
        assert updated_html =~ comic.id
        assert updated_html =~ comic.title
      end)

      assert has_element?(lv, "#top_pagination button.bg-blue-600", "#{page_num}")
    end)
  end

  test "verify search and sorting functionality", %{conn: conn} do
    comic_a = insert(:comic, title: "Amazing Spider-Man", format: :cbz)
    comic_b = insert(:comic, title: "Batman Detective", format: :pdf)
    comic_c = insert(:comic, title: "Superman Adventures", format: :cbz)
    comic_d = insert(:comic, title: "Wonder Woman", format: :cbr)

    _extra_comics = insert_list(5, :comic)

    assert {:ok, lv, _html} = live(conn, ~p"/")

    lv
    |> form("form", search_form: %{search_query: "Spider"})
    |> render_submit()

    html = render(lv)
    assert html =~ comic_a.title
    refute html =~ comic_b.title
    refute html =~ comic_c.title
    refute html =~ comic_d.title

    lv
    |> form("form", search_form: %{search_query: "", format_filter: "cbz"})
    |> render_submit()

    html = render(lv)
    assert html =~ comic_a.title
    assert html =~ comic_c.title
    refute html =~ comic_b.title
    refute html =~ comic_d.title

    lv
    |> form("form", search_form: %{search_query: "Spider", format_filter: "cbz"})
    |> render_submit()

    html = render(lv)

    assert html =~ comic_a.title
    refute html =~ comic_b.title

    refute html =~ comic_c.title
    refute html =~ comic_d.title

    lv
    |> form("form", search_form: %{search_query: "Spider", format_filter: "cbz"})
    |> render_submit()

    html = render(lv)
    assert html =~ comic_a.title
    refute html =~ comic_b.title

    lv
    |> element("button", "Reset")
    |> render_click()

    html = render(lv)

    assert html =~ comic_a.title
    assert html =~ comic_b.title
    assert html =~ comic_c.title
    assert html =~ comic_d.title

    refute has_element?(lv, "button", "Reset")
  end

  test "verify params", %{conn: conn} do
    _inserted_comics = insert_list(8 * 24, :comic)

    [chunk_1 | other_chunks] =
      Comics.list_comics(order_by: :title)
      |> Enum.chunk_every(24)

    assert {:ok, _lv, html} = live(conn, ~p"/?page=1")

    Enum.each(chunk_1, fn comic ->
      assert html =~ comic.id
      assert html =~ comic.title
    end)

    Enum.with_index(other_chunks, 2)
    |> Enum.each(fn {chunk, page_num} ->
      assert {:ok, _lv, html} = live(conn, ~p"/?page=#{page_num}")

      Enum.each(chunk, fn comic ->
        assert html =~ comic.id
        assert html =~ comic.title
      end)
    end)
  end
end
