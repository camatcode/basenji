defmodule BasenjiWeb.ComicsController do
  @moduledoc false
  use BasenjiWeb, :controller

  alias Basenji.Comics
  alias Basenji.ImageProcessor
  alias BasenjiWeb.API.Utils
  alias BasenjiWeb.PredictiveCache

  def get_page(conn, params) do
    id = params["id"]
    page = params["page"]
    opts = to_page_opts(params)

    with {:ok, page_num} <- Utils.safe_to_int(page),
         {:ok, comic} <- Comics.get_comic(id) do
      PredictiveCache.get_comic_page_from_cache(comic, page_num, opts)
    end
    |> case do
      {:ok, binary, mime} ->
        length = byte_size(binary)

        conn
        |> merge_resp_headers([{"access-control-allow-origin", "*"}])
        |> merge_resp_headers([{"content-type", mime}])
        |> merge_resp_headers([{"content-length", "#{length}"}])
        |> send_resp(200, binary)

      error ->
        Utils.bad_request_handler(conn, error)
    end
  end

  def get_preview(conn, params) do
    id = params["id"]

    get_comic_preview(id)
    |> case do
      {:ok, binary} ->
        length = byte_size(binary)

        conn
        |> merge_resp_headers([{"access-control-allow-origin", "*"}])
        |> merge_resp_headers([{"content-type", "image/jpeg"}])
        |> merge_resp_headers([{"content-length", "#{length}"}])
        |> send_resp(200, binary)

      error ->
        Utils.bad_request_handler(conn, error)
    end
  end

  defp get_comic_preview(id) do
    with {:ok, comic} <- Comics.get_comic(id) do
      Comics.get_image_preview(comic)
      |> case do
        {:ok, bytes} -> {:ok, bytes}
        _ -> make_preview(comic)
      end
    end
  end

  defp make_preview(comic) do
    with {:ok, bytes, mime} <- PredictiveCache.fetch_page_from_cache(comic, 1, []),
         {:ok, preview_bytes} <- ImageProcessor.get_image_preview(bytes, 400, 600) do
      Comics.associate_image_preview(comic, preview_bytes, width: 400, height: 600)
      {:ok, preview_bytes}
    end
  end

  defp to_page_opts(params) do
    width = params["width"]
    height = params["height"]

    opts = if width, do: [width: String.to_integer(width)], else: []
    if height, do: Keyword.put(opts, :height, String.to_integer(height)), else: opts
  end
end
