defmodule BasenjiWeb.ComicsController do
  @moduledoc false
  use BasenjiWeb, :controller

  alias Basenji.Comics
  alias BasenjiWeb.API.Utils

  def create(conn, params) do
    params = Utils.atomize(params)

    Comics.from_resource(params.resource_location, params)
    |> case do
      {:ok, comic} -> render(conn, "show.json", %{comic: comic})
      error -> Utils.bad_request_handler(conn, error)
    end
  end

  def list(conn, _params) do
    comics = Comics.list_comics()

    render(conn, "list.json", %{comics: comics})
  end

  def get(conn, params) do
    id = params["id"]

    Comics.get_comic(id)
    |> case do
      {:ok, comic} ->
        render(conn, "show.json", %{comic: comic})

      error ->
        Utils.bad_request_handler(conn, error)
    end
  end

  def update(conn, params) do
    id = params["id"]

    Comics.update_comic(id, params)
    |> case do
      {:ok, comic} -> render(conn, "show.json", %{comic: comic})
      error -> Utils.bad_request_handler(conn, error)
    end
  end

  def delete(conn, params) do
    id = params["id"]

    Comics.delete_comic(id)
    |> case do
      {:ok, comic} -> render(conn, "show.json", %{comic: comic})
      error -> Utils.bad_request_handler(conn, error)
    end
  end

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
