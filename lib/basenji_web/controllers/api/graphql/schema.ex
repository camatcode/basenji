defmodule BasenjiWeb.GraphQL.Schema do
  @moduledoc false
  use Absinthe.Schema

  alias Absinthe.Type.Custom
  alias BasenjiWeb.GraphQL.ComicsSchema

  import_types(Custom)
  import_types(ComicsSchema)

  query do
    import_fields(:comics_queries)
  end
end
