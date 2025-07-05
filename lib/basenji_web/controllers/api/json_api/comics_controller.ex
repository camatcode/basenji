defmodule BasenjiWeb.JSONAPI.ComicsController do
  @moduledoc false
  use BasenjiWeb, :controller

  alias Basenji.Comics
  alias BasenjiWeb.API.Utils
  alias BasenjiWeb.Plugs.JSONAPIPlug, as: BasenjiJSONAPIPlug

  plug BasenjiJSONAPIPlug, api: BasenjiWeb.API, path: "comics", resource: Basenji.Comic

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

  def show(%{private: %{jsonapi_plug: %{} = jsonapi_plug}} = conn, params) do
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
end
