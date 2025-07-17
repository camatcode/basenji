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

    with {:ok, page_num} <- Utils.safe_to_int(page),
         {:ok, comic} <- Comics.get_comic(id) do
      PredictiveCache.get_comic_page_from_cache(comic, page_num)
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
      if comic.image_preview do
        {:ok, comic.image_preview}
      else
        make_preview(comic)
      end
    end
  end

  defp make_preview(comic) do
    {:ok, bytes, _mime} = PredictiveCache.get_comic_page_from_cache(comic, 1)
    {:ok, preview_bytes} = ImageProcessor.get_image_preview(bytes, 600, 600)
    Comics.update_comic(comic, %{image_preview: preview_bytes})
    {:ok, preview_bytes}
  end
end
