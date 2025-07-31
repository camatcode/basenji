defmodule BasenjiWeb.ReadLiveTest do
  use BasenjiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BasenjiWeb.Comics.ReadLive

  @moduletag :capture_log

  doctest ReadLive

  test "load page / change", %{conn: conn} do
    comic = insert(:comic)
    assert {:ok, lv, _html} = live(conn, "/comics/#{comic.id}/read")
    assert has_element?(lv, ".landscape-image")
    assert has_element?(lv, ".next_page_nav")

    1..(comic.page_count - 1)
    |> Enum.each(fn page_num ->
      element(lv, ".next_page_nav")
      |> render_click()

      assert_patch(lv, "/comics/#{comic.id}/read?page=#{page_num + 1}")
    end)

    # start from somewhere else
    assert {:ok, lv, _html} = live(conn, "/comics/#{comic.id}/read?page=2")
    assert has_element?(lv, ".landscape-image")
    assert has_element?(lv, ".next_page_nav")
    assert has_element?(lv, ".previous_page_nav")

    element(lv, ".previous_page_nav")
    |> render_click()

    assert_patch(lv, "/comics/#{comic.id}/read?page=1")
  end

  test "key presses", %{conn: conn} do
    comic = insert(:comic)
    assert {:ok, lv, _html} = live(conn, "/comics/#{comic.id}/read?page=2")

    element(lv, "#reader-page-display")
    |> render_keydown(%{"key" => "ArrowLeft"})

    assert_patch(lv, "/comics/#{comic.id}/read?page=1")

    element(lv, "#reader-page-display")
    |> render_keydown(%{"key" => "ArrowRight"})

    assert_patch(lv, "/comics/#{comic.id}/read?page=2")
  end
end
