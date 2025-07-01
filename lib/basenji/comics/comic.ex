defmodule Basenji.Comic do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @formats [cbz: 0, cbt: 1, cb7: 2, cbr: 3]

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "comics" do
    field(:title, :string)
    field(:author, :string)
    field(:description, :string)
    field(:resource_location, :string)
    field(:released_year, :integer)
    field(:page_count, :integer)
    field(:format, Ecto.Enum, values: @formats)

    timestamps()
  end

  def changeset(comic, attrs) do
    comic
    |> cast(attrs, [
      :title,
      :author,
      :description,
      :resource_location,
      :released_year,
      :page_count,
      :format
    ])
    |> validate_required([:resource_location])
    |> validate_length(:title, max: 255, min: 3)
    |> validate_length(:author, max: 255, min: 3)
    |> validate_number(:released_year, greater_than: 0)
    |> validate_number(:page_count, greater_than: 0)
  end

  def formats, do: @formats |> Keyword.keys()
end
