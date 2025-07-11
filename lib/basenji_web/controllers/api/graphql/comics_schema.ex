defmodule BasenjiWeb.GraphQL.ComicsSchema do
  @moduledoc false
  use Absinthe.Schema.Notation

  import BasenjiWeb.GraphQL.CommonSchema

  alias BasenjiWeb.GraphQL.ComicsResolver

  object :comic do
    object_fields()
    field :resource_location, non_null(:string)
    field :title, :string
    field :author, :string
    field :description, :string
    field :released_year, :integer
    field :page_count, :integer
    field :pages, list_of(:string)
    field :format, :comic_format
    field :image_preview, :string
    field :byte_size, :integer
  end

  object :comics_queries do
    @desc "Lists comics"
    field :comics, list_of(:comic) do
      list_args()
      arg(:order_by, :comic_order_by, description: "Key to order results")

      arg(:title, :string)
      arg(:author, :string)
      arg(:description, :string)
      arg(:resource_location, :string)
      arg(:released_year, :integer)
      arg(:page_count, :integer)
      arg(:format, :comic_format)
      resolve(&ComicsResolver.list_comics/3)
    end

    @desc "Get a comic by ID"
    field :comic, :comic do
      arg(:id, non_null(:id))
      resolve(&ComicsResolver.get_comic/3)
    end
  end

  input_object :comic_input do
    field :title, :string
    field :author, :string
    field :description, :string
    field :resource_location, non_null(:string)
    field :released_year, :integer
    field :format, :comic_format
  end

  input_object :comic_update_input do
    field :title, :string
    field :author, :string
    field :description, :string
    field :released_year, :integer
  end

  object :comics_mutations do
    @desc "Create a new comic"
    field :create_comic, :comic do
      arg(:input, non_null(:comic_input))
      resolve(&ComicsResolver.create_comic/3)
    end

    @desc "Update an existing comic"
    field :update_comic, :comic do
      arg(:id, non_null(:id))
      arg(:input, non_null(:comic_update_input))
      resolve(&ComicsResolver.update_comic/3)
    end

    @desc "Delete a comic"
    field :delete_comic, :boolean do
      arg(:id, non_null(:id))
      resolve(&ComicsResolver.delete_comic/3)
    end
  end

  enum(:comic_format, values: ComicsResolver.formats())
  enum(:comic_order_by, values: ComicsResolver.order_by_attrs())
end
