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
    :format,
    :byte_size
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
    field(:byte_size, :integer, default: -1)

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
    |> cast(attrs, @attrs -- [:resource_location])
    |> validate_changeset()
  end

  defp validate_changeset(changeset) do
    changeset
    |> validate_required([:resource_location])
    |> validate_resource_location()
    |> validate_length(:title, max: 255, min: 3)
    |> validate_length(:author, max: 255, min: 3)
    |> validate_number(:released_year, greater_than: 0)
    |> validate_number(:page_count, greater_than: 0)
  end

  defp validate_resource_location(changeset) do
    resource_location = get_field(changeset, :resource_location)
    exists? = File.exists?(resource_location)

    if resource_location && exists? do
      changeset
      |> maybe_add_file_size(resource_location)
    else
      add_error(changeset, :resource_location, "resource_location does not exist #{inspect(resource_location)}")
    end
  end

  defp maybe_add_file_size(changeset, resource_location) do
    if get_field(changeset, :byte_size) && get_field(changeset, :byte_size) > -1 do
      changeset
    else
      %{size: size} = File.lstat!(resource_location)
      put_change(changeset, :byte_size, size)
    end
  end

  def formats, do: @formats |> Keyword.keys()

  def attrs, do: @attrs
end
