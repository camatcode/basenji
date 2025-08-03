defmodule Basenji.Comics.ComicPreview do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Basenji.Comics.Comic

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  @attrs [
    :image_data,
    :content_type,
    :width,
    :height,
    :comic_id
  ]

  schema "comic_previews" do
    field :image_data, :binary
    field :content_type, :string, default: "image/jpeg"
    field :width, :integer
    field :height, :integer

    belongs_to :comic, Comic
    timestamps(type: :utc_datetime)
  end

  def changeset(preview, attrs) do
    preview
    |> cast(attrs, @attrs)
    |> validate_required([:image_data, :comic_id])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> foreign_key_constraint(:comic_id)
    |> unique_constraint(:comic_id)
  end
end
