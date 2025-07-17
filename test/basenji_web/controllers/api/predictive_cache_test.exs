defmodule BasenjiWeb.PredictiveCacheTest do
  use Basenji.DataCase

  alias BasenjiWeb.PredictiveCache

  doctest PredictiveCache

  test "predictive cache" do
    comic = insert(:comic)
    %{active_prefetches: %{}, completed_prefetch_count: 0} = PredictiveCache.get_state()
    PredictiveCache.get_comic_page_from_cache(comic, 1)
    :timer.sleep(5_000)
    %{completed_prefetch_count: 1} = PredictiveCache.get_state()
  end
end
