defmodule BasenjiWeb.PredictiveCacheTest do
  use Basenji.DataCase

  alias Basenji.Comics
  alias BasenjiWeb.PredictiveCache

  doctest PredictiveCache

  test "predictive cache" do
    comic = insert(:comic)
    {:ok, page, _mime} = Comics.get_page(comic, 1)

    %{active_prefetches: %{}} = PredictiveCache.get_state()
    # No resize opts
    {:ok, bytes, _mime} = PredictiveCache.get_comic_page_from_cache(comic, 1)
    assert bytes == page

    requested_width = 1920
    requested_height = 1080

    # resize width
    {:ok, bytes, _mime} = PredictiveCache.get_comic_page_from_cache(comic, 1, width: requested_width)
    assert bytes != page
    resized_w_image = Image.from_binary!(bytes)
    assert Image.width(resized_w_image) == requested_width

    # resize height
    {:ok, bytes, _mime} = PredictiveCache.get_comic_page_from_cache(comic, 1, height: requested_height)
    assert bytes != page
    resized_h_image = Image.from_binary!(bytes)
    assert Image.height(resized_h_image) == requested_height

    # force size
    {:ok, bytes, _mime} =
      PredictiveCache.get_comic_page_from_cache(comic, 1, width: requested_width, height: requested_height)

    assert bytes != page
    forced_size_image = Image.from_binary!(bytes)
    assert Image.width(forced_size_image) == requested_width
    assert Image.height(forced_size_image) == requested_height

    :timer.sleep(5_000)
    %{completed_prefetch_count: count} = PredictiveCache.get_state()
    assert count > 0
  end
end
