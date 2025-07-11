defmodule BasenjiWeb.GraphQL.CollectionsResolver do
  @moduledoc false
  alias Basenji.Collections
  alias BasenjiWeb.GraphQL.GraphQLUtils

  def list_collections(_root, args, _info) do
    opts = Map.to_list(args)
    collections = Collections.list_collections(opts)
    {:ok, collections}
  end

  def get_collection(_root, %{id: id} = args, _info) do
    opts = Map.to_list(args)

    case Collections.get_collection(id, opts) do
      {:ok, collection} -> {:ok, collection}
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def create_collection(_root, %{input: attrs}, _info) do
    case Collections.create_collection(attrs) do
      {:ok, collection} -> {:ok, collection}
      error -> GraphQLUtils.handle_result(error)
    end
  end

  def update_collection(_root, %{id: id, input: attrs}, _info) do
    case Collections.update_collection(id, attrs) do
      {:ok, collection} -> {:ok, collection}
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
end
