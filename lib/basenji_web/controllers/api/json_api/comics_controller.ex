defmodule BasenjiWeb.JSONAPI.ComicsController do
  @moduledoc false
  use BasenjiWeb, :controller

  alias Basenji.Comics
  alias Basenji.Comics.Comic
  alias BasenjiWeb.API.Utils
  alias BasenjiWeb.Plugs.JSONAPIPlug, as: BasenjiJSONAPIPlug

  plug BasenjiJSONAPIPlug, api: BasenjiWeb.API, path: "comics", resource: Comic

  def index(%{private: %{jsonapi_plug: jsonapi_plug}} = conn, _params) do
    opts = Utils.to_opts(jsonapi_plug)
    # Default to prefer_optimized unless explicitly set to false
    opts =
      if Keyword.has_key?(opts, :prefer_optimized) do
        opts
      else
        Keyword.put(opts, :prefer_optimized, true)
      end

    comics = Comics.list_comics(opts)
    render(conn, "index.json", %{data: comics})
  end

  def create(%{private: %{jsonapi_plug: jsonapi_plug}} = conn, params) do
    # validate params!
    attrs = params["data"]["attributes"] |> Utils.atomize()

    Comics.from_resource(params["data"]["attributes"]["resource_location"], attrs, Utils.to_opts(jsonapi_plug))
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
