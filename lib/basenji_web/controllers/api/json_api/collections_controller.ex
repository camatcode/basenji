defmodule BasenjiWeb.JSONAPI.CollectionsController do
  @moduledoc false
  use BasenjiWeb, :controller

  alias Basenji.Collections
  alias BasenjiWeb.API.Utils
  alias BasenjiWeb.Plugs.JSONAPIPlug, as: BasenjiJSONAPIPlug

  plug BasenjiJSONAPIPlug, api: BasenjiWeb.API, path: "collections", resource: Basenji.Collection

  def index(%{private: %{jsonapi_plug: jsonapi_plug}} = conn, _params) do
    collections = Collections.list_collections(Utils.to_opts(jsonapi_plug))
    render(conn, "index.json", %{data: collections})
  end

  def create(%{private: %{jsonapi_plug: jsonapi_plug}} = conn, params) do
    # validate params!
    attrs = params["data"]["attributes"] |> Utils.atomize()

    Collections.create_collection(attrs, Utils.to_opts(jsonapi_plug))
    |> case do
      {:ok, collection} ->
        render(conn, "create.json", %{data: collection})

      error ->
        Utils.bad_request_handler(conn, error)
    end
  end

  def show(%{private: %{jsonapi_plug: jsonapi_plug}} = conn, params) do
    Collections.get_collection(params["id"], Utils.to_opts(jsonapi_plug))
    |> case do
      {:ok, comic} ->
        render(conn, "create.json", %{data: comic})

      _ ->
        Utils.bad_request_handler(conn, {:error, :not_found})
    end
  end

  def update(%{private: %{jsonapi_plug: jsonapi_plug}} = conn, params) do
    id = params["id"]

    Collections.update_collection(id, params["data"]["attributes"], Utils.to_opts(jsonapi_plug))
    |> case do
      {:ok, collection} -> render(conn, "update.json", %{data: collection})
      e -> Utils.bad_request_handler(conn, e)
    end
  end

  def delete(conn, params) do
    {:ok, deleted} = Collections.delete_collection(params["id"])
    render(conn, "show.json", %{data: deleted})
  end
end
