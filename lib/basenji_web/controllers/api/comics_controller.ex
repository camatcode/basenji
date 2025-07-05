defmodule BasenjiWeb.ComicsController do
  @moduledoc false
  use BasenjiWeb, :controller

  alias Basenji.Comics
  alias BasenjiWeb.API.Utils
  alias BasenjiWeb.Plugs.JSONAPIPlug

  plug JSONAPIPlug, api: BasenjiWeb.API, path: "comics", resource: Basenji.Comic

  def index(%{private: %{jsonapi_plug: jsonapi_plug}} = conn, _params) do
    comics = Comics.list_comics(Utils.to_opts(jsonapi_plug))
    render(conn, "index.json", %{data: comics})
  end

  def create(conn, params) do
    # validate params!
    attrs = params["data"]["attributes"] |> Utils.atomize()

    Comics.from_resource(params["data"]["attributes"]["resource_location"], attrs)
    |> case do
      {:ok, comic} -> render(conn, "create.json", %{data: comic})
      error -> Utils.bad_request_handler(conn, error)
    end
  end

  def show(%{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn, params) do
    Comics.get_comic(params["id"], Utils.to_opts(jsonapi_plug))
    |> case do
      {:ok, comic} ->
        render(conn, "create.json", %{data: comic})

      _ ->
        Utils.bad_request_handler(conn, {:error, :not_found})
    end
  end

  def update(conn, params) do
    id = params["id"]

    Comics.update_comic(id, params["data"]["attributes"])
    |> case do
      {:ok, comic} -> render(conn, "update.json", %{data: comic})
      e -> Utils.bad_request_handler(conn, e)
    end
  end

  def delete(conn, params) do
    {:ok, deleted} = Comics.delete_comic(params["id"])
    render(conn, "show.json", %{data: deleted})
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
