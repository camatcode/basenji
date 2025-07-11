defmodule BasenjiWeb.GraphQL.ComicsSchema do
  @moduledoc false
  use Absinthe.Schema.Notation

  import BasenjiWeb.GraphQL.CommonSchema

  alias BasenjiWeb.GraphQL.ComicsResolver
  alias BasenjiWeb.GraphQL.GraphQLUtils

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
      arg(:title, :string)
      arg(:author, :string)
      arg(:description, :string)
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

  enum(:comic_format, values: ComicsResolver.formats())
end
