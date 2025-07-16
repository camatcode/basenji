defmodule BasenjiWeb.ComicsController do
  @moduledoc false
  use BasenjiWeb, :controller

  alias Basenji.Comics
  alias BasenjiWeb.API.Utils

  def get_page(conn, params) do
    id = params["id"]
    page = params["page"]

    with {:ok, page_num} <- Utils.safe_to_int(page) do
      Comics.get_page(id, page_num)
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

    Comics.get_image_preview(id)
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
end
