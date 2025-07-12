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

    # Handle both attributes and relationships
    attrs = params["data"]["attributes"] |> Utils.atomize()
    relationships = Map.get(params["data"], "relationships", %{})

    # If comics relationship is provided, handle it
    attrs_with_relationships =
      case Map.get(relationships, "comics") do
        %{"data" => comics_data} when is_list(comics_data) ->
          # For JSON:API, we replace the entire relationship
          new_comic_ids = Enum.map(comics_data, fn %{"id" => id} -> id end)

          # Get current comics to determine what to add/remove
          case Collections.get_collection(id, preload: [:comics]) do
            {:ok, current_collection} ->
              current_comic_ids = Enum.map(current_collection.comics, & &1.id)
              comics_to_add = new_comic_ids -- current_comic_ids
              comics_to_remove = current_comic_ids -- new_comic_ids

              attrs
              |> Map.put(:comics_to_add, comics_to_add)
              |> Map.put(:comics_to_remove, comics_to_remove)

            _ ->
              attrs
          end

        _ ->
          attrs
      end

    Collections.update_collection(id, attrs_with_relationships, Utils.to_opts(jsonapi_plug))
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
