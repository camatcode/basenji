defmodule Basenji.Comics.Comic do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Basenji.Collections.Collection
  alias Basenji.Comics.Comic
  alias Basenji.Comics.ComicPreview

  @formats [cbz: 0, cbt: 1, cb7: 2, cbr: 3, pdf: 4]

  @attrs [
    :title,
    :author,
    :description,
    :resource_location,
    :released_year,
    :page_count,
    :format,
    :hash,
    :byte_size,
    :original_id,
    :optimized_id,
    :image_preview_id,
    :pre_optimized?
  ]

  @cloneable_attrs [:title, :author, :description, :released_year, :page_count, :format]

  @derive {
    JSONAPIPlug.Resource,
    type: "comic",
    attributes: (@attrs -- [:image_preview]) ++ [:updated_at, :inserted_at],
    relationships: [
      member_collections: [many: true, resource: Collection],
      original_comic: [resource: Comic],
      optimized_comic: [resource: Comic],
      image_preview: [resource: ComicPreview]
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
    field(:hash, :string)
    field(:byte_size, :integer, default: -1)
    field(:optimized_id, :binary_id)
    field(:image_preview_id, :binary_id)
    field(:pre_optimized?, :boolean)

    belongs_to(:original_comic, Comic, foreign_key: :original_id, type: :binary_id)
    has_one(:optimized_comic, Comic, foreign_key: :original_id)
    has_one(:image_preview, ComicPreview, foreign_key: :id)

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
    |> unique_constraint([:resource_location])
    |> maybe_validate_optimization()
  end

  defp maybe_validate_optimization(changeset) do
    if get_change(changeset, :original_id) || get_change(changeset, :optimized_id) do
      changeset
      |> validate_no_optimization_chain()
      |> validate_no_double_optimization()
    else
      changeset
    end
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

  def cloneable_attrs, do: @cloneable_attrs

  def clone_attrs(original_comic, overrides \\ %{}) do
    original_comic
    |> Map.from_struct()
    |> Map.take(@cloneable_attrs)
    |> Map.merge(overrides)
    |> Map.put(:original_id, original_comic.id)
  end

  defp validate_no_optimization_chain(changeset) do
    original_id = get_field(changeset, :original_id)

    case fetch_field(changeset, :optimized_id) do
      {_, optimized_id} when not is_nil(original_id) and not is_nil(optimized_id) ->
        add_error(changeset, :original_id, "Comic cannot be both original and optimized")

      _ ->
        changeset
    end
  end

  defp validate_no_double_optimization(changeset) do
    case get_field(changeset, :original_id) do
      nil ->
        changeset

      original_id ->
        case Basenji.Repo.get(Comic, original_id) do
          nil ->
            add_error(changeset, :original_id, "Original comic not found")

          %Comic{optimized_id: nil} ->
            changeset

          %Comic{optimized_id: _existing} ->
            add_error(changeset, :original_id, "Original comic already has an optimized version")
        end
    end
  end
end
