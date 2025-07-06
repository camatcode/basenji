defmodule BasenjiWeb.ComicsController do
  @moduledoc false
  use BasenjiWeb, :controller

  alias Basenji.Comics
  alias BasenjiWeb.API.Utils

  def get_page(conn, params) do
    id = params["id"]
    page = params["page"]

    with {:ok, page_num} <- Utils.safe_to_int(page),
         {:ok, page_stream, mime} <- Comics.get_page(id, page_num) do
      binary = page_stream |> Enum.to_list()
      {:ok, binary, mime}
    end
    |> case do
      {:ok, binary, mime} ->
        length = Enum.count(binary)

        conn
        |> merge_resp_headers([{"access-control-allow-origin", "*"}])
        |> merge_resp_headers([{"content-type", mime}])
        |> merge_resp_headers([{"content-length", "#{length}"}])
        |> merge_resp_headers([{"content-disposition", "attachment"}])
        |> send_resp(200, binary)

      error ->
        Utils.bad_request_handler(conn, error)
    end
  end
end
