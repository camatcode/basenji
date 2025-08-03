defmodule Basenji.Collections.CollectionComic do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Basenji.Collections.Collection
  alias Basenji.Comics.Comic

  require Logger

  schema "collection_comics" do
    belongs_to(:collection, Collection, type: Ecto.UUID)
    belongs_to(:comic, Comic, type: Ecto.UUID)

    timestamps(type: :utc_datetime)
  end

  def changeset(collection_comic, attrs \\ %{}) do
    collection_comic
    |> cast(attrs, [:collection_id, :comic_id])
    |> validate_required([:collection_id, :comic_id])
    |> foreign_key_constraint(:collection_id)
    |> foreign_key_constraint(:comic_id)
  end
end
