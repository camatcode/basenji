defmodule BasenjiWeb.ComicReaderLiveTest do
  use BasenjiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BasenjiWeb.ComicReaderLive.{ComicProcessor, NavigationHelpers}

  test "comic reader mounts successfully", %{conn: conn} do
    {:ok, _lv, html} = live(conn, "/reader")

    # Check that the page renders
    assert html =~ "Basenji Comic Reader"
    assert html =~ "Upload a Comic"
    assert html =~ "Supported formats: CBZ, CBR, CB7, CBT"
  end

  test "validates file extensions", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/reader")

    # Test that the upload form is present
    assert has_element?(lv, "form[phx-submit=upload]")

    # Test file input is present
    assert has_element?(lv, "input[type=file]")
  end

  describe "ComicProcessor" do
    test "supported_comic_extension?/1" do
      assert ComicProcessor.supported_comic_extension?("test.cbz") == true
      assert ComicProcessor.supported_comic_extension?("test.cbr") == true
      assert ComicProcessor.supported_comic_extension?("test.cb7") == true
      assert ComicProcessor.supported_comic_extension?("test.cbt") == true
      assert ComicProcessor.supported_comic_extension?("test.CBZ") == true
      assert ComicProcessor.supported_comic_extension?("test.pdf") == false
      assert ComicProcessor.supported_comic_extension?("test.jpg") == false
    end
  end

  describe "NavigationHelpers" do
    test "next_page/3" do
      # Single page mode
      assert NavigationHelpers.next_page(0, 10, "single") == 1
      assert NavigationHelpers.next_page(8, 10, "single") == 9
      # Can't go past last page
      assert NavigationHelpers.next_page(9, 10, "single") == 9

      # Double page mode
      assert NavigationHelpers.next_page(0, 10, "double") == 2
      assert NavigationHelpers.next_page(7, 10, "double") == 9
      # Can't go past last page
      assert NavigationHelpers.next_page(8, 10, "double") == 9
    end

    test "prev_page/2" do
      # Single page mode
      assert NavigationHelpers.prev_page(5, "single") == 4
      assert NavigationHelpers.prev_page(1, "single") == 0
      # Can't go before first page
      assert NavigationHelpers.prev_page(0, "single") == 0

      # Double page mode
      assert NavigationHelpers.prev_page(5, "double") == 3
      assert NavigationHelpers.prev_page(2, "double") == 0
      assert NavigationHelpers.prev_page(1, "double") == 0
      # Can't go before first page
      assert NavigationHelpers.prev_page(0, "double") == 0
    end

    test "parse_page_number/2" do
      # Converts to 0-based
      assert NavigationHelpers.parse_page_number("5", 10) == {:ok, 4}
      assert NavigationHelpers.parse_page_number("1", 10) == {:ok, 0}
      assert NavigationHelpers.parse_page_number("10", 10) == {:ok, 9}
      assert NavigationHelpers.parse_page_number("0", 10) == {:error, "Invalid page number"}
      assert NavigationHelpers.parse_page_number("11", 10) == {:error, "Invalid page number"}
      assert NavigationHelpers.parse_page_number("abc", 10) == {:error, "Invalid page number"}
    end

    test "can_go_next?/3" do
      assert NavigationHelpers.can_go_next?(0, 10, "single") == true
      assert NavigationHelpers.can_go_next?(8, 10, "single") == true
      assert NavigationHelpers.can_go_next?(9, 10, "single") == false

      assert NavigationHelpers.can_go_next?(0, 10, "double") == true
      assert NavigationHelpers.can_go_next?(7, 10, "double") == true
      assert NavigationHelpers.can_go_next?(8, 10, "double") == false
    end

    test "can_go_prev?/1" do
      assert NavigationHelpers.can_go_prev?(0) == false
      assert NavigationHelpers.can_go_prev?(1) == true
      assert NavigationHelpers.can_go_prev?(5) == true
    end
  end
end
