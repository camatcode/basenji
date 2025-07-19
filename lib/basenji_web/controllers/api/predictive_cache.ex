defmodule BasenjiWeb.PredictiveCache do
  @moduledoc false

  use GenServer

  alias __MODULE__, as: PredictiveCache
  alias Basenji.Comic
  alias Basenji.Comics
  alias Basenji.ImageProcessor

  require Logger

  @prefetch_count 4
  @prefetch_behind 2
  @max_concurrent_prefetches 3
  @prefetch_delay 100

  def start_link(state) do
    GenServer.start_link(PredictiveCache, state, name: PredictiveCache)
  end

  def init(_opts) do
    {:ok,
     %{
       active_prefetches: %{},
       completed_prefetch_count: 0
     }}
  end

  def get_state do
    GenServer.call(PredictiveCache, :state)
  end

  def get_comic_page_from_cache(%Comic{} = comic, page_num, opts \\ []) do
    result = fetch_page_from_cache(comic, page_num, opts)

    prefetch_next_pages(comic, page_num, opts)

    result
  end

  # for testing / probing
  def handle_call(:state, _, state) do
    {:reply, state, state}
  end

  def handle_cast({:prefetch, comic, current_page, opts}, state) do
    Process.send_after(self(), {:do_prefetch, comic, current_page, opts}, @prefetch_delay)
    {:noreply, state}
  end

  def handle_cast({:prefetch_complete, prefetch_key}, state) do
    prefetches = Map.delete(state.active_prefetches, prefetch_key)
    count = state.completed_prefetch_count + 1
    {:noreply, %{active_prefetches: prefetches, completed_prefetch_count: count}}
  end

  def handle_info({:do_prefetch, comic, current_page, opts}, state) do
    prefetch_key = "#{comic.id}_#{current_page}_#{inspect(opts)}"

    if Map.has_key?(state.active_prefetches, prefetch_key) do
      {:noreply, state}
    else
      task =
        Task.start(fn ->
          prefetch_pages(comic, current_page, opts)
          GenServer.cast(PredictiveCache, {:prefetch_complete, prefetch_key})
        end)

      new_state = Map.put(state, :active_prefetches, Map.put(state.active_prefetches, prefetch_key, task))
      {:noreply, new_state}
    end
  end

  defp prefetch_pages(comic, current_page, opts) do
    max_page = comic.page_count

    forward_pages = calculate_forward_pages(current_page, max_page)
    backward_pages = calculate_backward_pages(current_page)

    all_pages = forward_pages ++ backward_pages

    Logger.debug("Prefetching pages #{inspect(all_pages)} for comic #{comic.id} with #{inspect(opts)}")

    all_pages
    |> Task.async_stream(
      fn page_num -> prefetch_single_page(comic, page_num, opts) end,
      max_concurrency: @max_concurrent_prefetches,
      timeout: 30_000
    )
    |> Stream.run()
  end

  defp calculate_forward_pages(current_page, max_page) do
    (current_page + 1)..(current_page + @prefetch_count)
    |> Enum.to_list()
    |> Enum.filter(&(&1 <= max_page))
  end

  defp calculate_backward_pages(current_page) do
    start_page = max(1, current_page - @prefetch_behind)
    end_page = current_page - 1

    if end_page >= start_page do
      start_page..end_page
      |> Enum.to_list()
      |> Enum.reverse()
    else
      []
    end
  end

  defp prefetch_single_page(comic, page_num, opts) do
    cache_key = page_cache_key(comic.id, page_num, opts)

    case Cachex.exists?(:basenji_cache, cache_key) do
      {:ok, false} ->
        case fetch_page_from_cache(comic, page_num, opts) do
          {:ok, _data, _mime} ->
            Logger.debug("Prefetched page #{page_num} for comic #{comic.id}")
            :ok

          _ ->
            :error
        end

      {:ok, true} ->
        :cached

      error ->
        Logger.warning("Cache check failed for page #{page_num}: #{inspect(error)}")
        :error
    end
  end

  defp page_cache_key(comic_id, page_num, opts) do
    %{comic_id: comic_id, page_num: page_num, optimized: true, opts: opts}
  end

  defp fetch_page_from_cache(%Comic{id: comic_id} = comic, page_num, opts) do
    Cachex.fetch(
      :basenji_cache,
      page_cache_key(comic_id, page_num, opts),
      fn _key ->
        with {:ok, page, _mime} <- Comics.get_page(comic, page_num) do
          ImageProcessor.resize_image(page, opts)
        end
        |> case do
          {:ok, page} ->
            {:commit, {page, "image/jpeg"}, [ttl: to_timeout(minute: 1)]}

          {_, resp} ->
            {:ignore, {:error, resp}}
        end
      end
    )
    |> case do
      {:ignore, {:error, error}} ->
        {:error, error}

      {_, {page, mime}} ->
        {:ok, page, mime}

      response ->
        response
    end
  end

  defp prefetch_next_pages(%Comic{} = comic, current_page, opts) do
    GenServer.cast(PredictiveCache, {:prefetch, comic, current_page, opts})
  end
end
