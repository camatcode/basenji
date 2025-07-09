defmodule BasenjiWeb.Schema do
  @moduledoc """
  Main GraphQL schema for Basenji API
  """
  use Absinthe.Schema

  alias BasenjiWeb.GraphQL.ComicsSchema

  import_types(ComicsSchema)

  query do
    import_fields(:comics_queries)
  end
end
