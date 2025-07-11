defmodule BasenjiWeb.GraphQL.CollectionsResolver do
  @moduledoc false
  alias Basenji.Collections
  alias BasenjiWeb.GraphQL.GraphQLUtils

  @preload_mapping %{
    "parent" => :parent,
    "comics" => :comics
  }

  def list_collections(_root, args, info) do
    preload_opts = GraphQLUtils.extract_preloads(info, @preload_mapping)
    opts = Map.to_list(args) ++ preload_opts
    collections = Collections.list_collections(opts)
    {:ok, collections}
  end

  def get_collection(_root, %{id: id} = args, info) do
    preload_opts = GraphQLUtils.extract_preloads(info, @preload_mapping)
    opts = Map.to_list(args) ++ preload_opts

    case Collections.get_collection(id, opts) do
      {:ok, collection} -> {:ok, collection}
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def create_collection(_root, %{input: attrs}, info) do
    case Collections.create_collection(attrs) do
      {:ok, collection} -> maybe_preload_collection(collection, info)
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def update_collection(_root, %{id: id, input: attrs}, info) do
    case Collections.update_collection(id, attrs) do
      {:ok, collection} -> maybe_preload_collection(collection, info)
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def delete_collection(_root, %{id: id}, _info) do
    case Collections.delete_collection(id) do
      {:ok, _deleted} -> {:ok, true}
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def order_by_attrs, do: Collections.attrs()

  defp maybe_preload_collection(collection, info) do
    preload_opts = GraphQLUtils.extract_preloads(info, @preload_mapping)

    if Enum.empty?(preload_opts) do
      {:ok, collection}
    else
      Collections.get_collection(collection.id, preload_opts)
    end
  end
end
