defmodule Basenji.Comic do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Basenji.Collection

  @formats [cbz: 0, cbt: 1, cb7: 2, cbr: 3]

  @attrs [
    :title,
    :author,
    :image_preview,
    :description,
    :resource_location,
    :released_year,
    :page_count,
    :format
  ]

  @derive {
    JSONAPIPlug.Resource,
    type: "comic",
    attributes: (@attrs -- [:image_preview]) ++ [:updated_at, :inserted_at],
    relationships: [
      member_collections: [many: true, resource: Basenji.Collection]
    ]
  }

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "comics" do
    field(:title, :string)
    field(:author, :string)
    field(:description, :string)
    field(:resource_location, :string)
    field(:released_year, :integer, default: -1)
    field(:page_count, :integer, default: -1)
    field(:format, Ecto.Enum, values: @formats)
    field(:image_preview, :binary)

    many_to_many(:member_collections, Collection,
      join_through: "collection_comics",
      join_keys: [comic_id: :id, collection_id: :id]
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(comic, attrs) do
    comic
    |> cast(attrs, @attrs)
    |> validate_changeset()
  end

  def update_changeset(comic, attrs) do
    comic
    |> cast(attrs, @attrs)
    |> validate_changeset()
  end

  defp validate_changeset(changeset) do
    changeset
    |> validate_required([:resource_location])
    |> validate_length(:title, max: 255, min: 3)
    |> validate_length(:author, max: 255, min: 3)
    |> validate_number(:released_year, greater_than: 0)
    |> validate_number(:page_count, greater_than: 0)
  end

  def formats, do: @formats |> Keyword.keys()

  def attrs, do: @attrs
end
