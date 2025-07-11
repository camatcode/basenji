defmodule BasenjiWeb.GraphQL.Schema do
  @moduledoc false
  use Absinthe.Schema

  alias Absinthe.Type.Custom
  alias BasenjiWeb.GraphQL.CollectionsSchema
  alias BasenjiWeb.GraphQL.ComicsSchema

  import_types(Custom)
  import_types(ComicsSchema)
  import_types(CollectionsSchema)

  query do
    import_fields(:comics_queries)
    import_fields(:collections_queries)
  end

  mutation do
    import_fields(:comics_mutations)
    import_fields(:collections_mutations)
  end
end
