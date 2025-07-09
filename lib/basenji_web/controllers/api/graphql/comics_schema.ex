defmodule BasenjiWeb.GraphQL.ComicsSchema do
  @moduledoc false
  use Absinthe.Schema.Notation

  alias BasenjiWeb.GraphQL.ComicsResolver

  object :comic do
    field :id, non_null(:id)
    field :resource_location, non_null(:string)
    field :title, :string
    field :author, :string
    field :description, :string
    field :released_year, :integer
    field :page_count, :integer
    field :format, :string
    field :image_preview, :string
    field :byte_size, :integer
  end

  object :comics_queries do
    @desc "Lists comics"
    field :list_comics, non_null(list_of(non_null(:comic))) do
      resolve(&ComicsResolver.list_comics/3)
    end

    @desc "Get a comic by ID"
    field :comic, :comic do
      arg(:id, non_null(:id))
      resolve(&ComicsResolver.get_comic/3)
    end
  end
end
