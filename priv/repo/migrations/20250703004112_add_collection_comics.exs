defmodule Basenji.Repo.Migrations.AddCollectionComics do
  use Ecto.Migration

  def change do
    create table(:collection_comics) do
      add :comic_id, references(:comics, type: :uuid, on_delete: :delete_all), null: false

      add :collection_id, references(:collections, type: :uuid, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collection_comics, [:comic_id, :collection_id])
  end
end
