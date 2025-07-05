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

  def create(conn, params) do
    # validate params!
   # attrs = params["data"]["attributes"] |> Utils.atomize()

#    Comics.from_resource(params["data"]["attributes"]["resource_location"], attrs)
#    |> case do
#         {:ok, comic} -> render(conn, "create.json", %{data: comic})
#         error -> Utils.bad_request_handler(conn, error)
#       end
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
end
