defmodule Basenji.Collection do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Basenji.Collection
  alias Basenji.CollectionComic
  alias Basenji.Comic
  alias Basenji.Repo

  require Logger

  @attrs [
    :title,
    :description,
    :parent_id,
    :resource_location
  ]

  @derive {
    JSONAPIPlug.Resource,
    type: "collection",
    attributes: @attrs ++ [:updated_at, :inserted_at],
    relationships: [
      parent: [resource: Basenji.Collection],
      comics: [many: true, resource: Basenji.Comic]
    ]
  }
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "collections" do
    field(:title, :string)
    field(:description, :string)
    field(:resource_location, :string)

    has_many(:collection_comics, CollectionComic)
    many_to_many(:comics, Comic, join_through: "collection_comics", join_keys: [collection_id: :id, comic_id: :id])

    belongs_to(:parent, Collection, foreign_key: :parent_id, type: Ecto.UUID)

    timestamps(type: :utc_datetime)
  end

  def changeset(collection, attrs \\ %{}) do
    collection
    |> Repo.preload(:collection_comics)
    |> cast(attrs, @attrs)
    |> cast_assoc(:collection_comics, with: &CollectionComic.changeset/2)
    |> validate_required([:title])
    |> foreign_key_constraint(:parent_id)
    |> validate_not_self_parent()
    |> unique_constraint([:title])
  end

  defp validate_not_self_parent(changeset) do
    if get_field(changeset, :id) && get_field(changeset, :id) == get_field(changeset, :parent_id) do
      add_error(changeset, :parent_id, "cannot be their own parent")
    else
      changeset
    end
  end
end
