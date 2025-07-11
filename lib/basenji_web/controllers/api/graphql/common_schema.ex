defmodule BasenjiWeb.GraphQL.CommonSchema do
  @moduledoc false
  use Absinthe.Schema.Notation

  defmacro object_fields do
    quote do
      field :id, non_null(:id)
      field :updated_at, :datetime, description: "When this object was last updated"
      field :inserted_at, :datetime, description: "When this object was first known to Basenji"
    end
  end

  defmacro list_args do
    quote do
      arg(:limit, :integer, description: "Number of items to return")
      arg(:offset, :integer, description: "Number of items to skip")
      arg(:search, :string, description: "Search term")
      arg(:inserted_before, :datetime, description: "Only results inserted before this DateTime")
      arg(:inserted_after, :datetime, description: "Only results inserted after this DateTime")
      arg(:updated_before, :datetime, description: "Only results updated before this DateTime")
      arg(:updated_after, :datetime, description: "Only results updated after this DateTime")
    end
  end
end
