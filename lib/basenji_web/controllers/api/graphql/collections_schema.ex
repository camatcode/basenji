defmodule BasenjiWeb.GraphQL.CollectionsSchema do
  @moduledoc false
  use Absinthe.Schema.Notation

  import BasenjiWeb.GraphQL.CommonSchema

  alias BasenjiWeb.GraphQL.CollectionsResolver

  object :collection do
    object_fields()
    field :title, non_null(:string)
    field :description, :string
    field :resource_location, :string

    field :parent, :collection
  end

  object :collections_queries do
    @desc "List collections"
    field :collections, non_null(list_of(non_null(:collection))) do
      list_args()
      arg(:order_by, :collection_order_by, description: "Key to order results")
      arg(:title, :string)
      arg(:description, :string)
      resolve(&CollectionsResolver.list_collections/3)
    end

    @desc "Get a collection by ID"
    field :collection, :collection do
      arg(:id, non_null(:id))
      resolve(&CollectionsResolver.get_collection/3)
    end
  end

  input_object :collection_input do
    field :title, non_null(:string)
    field :description, :string
    field :resource_location, :string
  end

  input_object :collection_update_input do
    field :title, :string
    field :description, :string
    field :resource_location, :string
  end

  object :collections_mutations do
    @desc "Create a new collection"
    field :create_collection, :collection do
      arg(:input, non_null(:collection_input))
      resolve(&CollectionsResolver.create_collection/3)
    end

    @desc "Update an existing collection"
    field :update_collection, :collection do
      arg(:id, non_null(:id))
      arg(:input, non_null(:collection_update_input))
      resolve(&CollectionsResolver.update_collection/3)
    end

    @desc "Delete a collection"
    field :delete_collection, :boolean do
      arg(:id, non_null(:id))
      resolve(&CollectionsResolver.delete_collection/3)
    end
  end

  enum(:collection_order_by, values: CollectionsResolver.order_by_attrs())
end
