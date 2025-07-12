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

    attrs = extract_attributes(params)
    relationships = Map.get(params["data"], "relationships", %{})

    try do
      final_attrs =
        attrs
        |> maybe_add_comics_operations(id, relationships)

      Collections.update_collection(id, final_attrs, Utils.to_opts(jsonapi_plug))
      |> case do
        {:ok, collection} -> render(conn, "update.json", %{data: collection})
        e -> Utils.bad_request_handler(conn, e)
      end
    rescue
      e in ArgumentError ->
        Utils.bad_request_handler(conn, {:error, Exception.message(e)})
    end
  end

  def delete(conn, params) do
    {:ok, deleted} = Collections.delete_collection(params["id"])
    render(conn, "show.json", %{data: deleted})
  end

  # Helper functions
  defp extract_attributes(params) do
    case Map.get(params["data"], "attributes") do
      nil -> %{}
      attributes -> Utils.atomize(attributes)
    end
  end

  defp maybe_add_comics_operations(attrs, collection_id, relationships) do
    case Map.get(relationships, "comics") do
      %{"data" => comics_data} when is_list(comics_data) ->
        add_comics_operations(attrs, collection_id, comics_data)

      _ ->
        attrs
    end
  end

  defp add_comics_operations(attrs, collection_id, comics_data) do
    new_comic_ids = Enum.map(comics_data, fn %{"id" => id} -> id end)

    case validate_uuids(new_comic_ids) do
      :ok ->
        case Collections.get_collection(collection_id, preload: [:comics]) do
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

      {:error, invalid_id} ->
        raise ArgumentError, "Invalid UUID format: #{invalid_id}"
    end
  end

  defp validate_uuids(ids) do
    Enum.find_value(ids, :ok, fn id ->
      case Ecto.UUID.cast(id) do
        {:ok, _} -> nil
        :error -> {:error, id}
      end
    end)
  end
end
