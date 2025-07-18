defmodule Basenji.Repo.Migrations.SeparateComicPreviews do
  use Ecto.Migration

  def change do
    create table(:comic_previews, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :comic_id, references(:comics, type: :uuid, on_delete: :delete_all), null: false
      add :image_data, :binary, null: false
      add :content_type, :string, null: false, default: "image/jpeg"
      add :width, :integer
      add :height, :integer

      timestamps(type: :utc_datetime)
    end

    alter table(:comics) do
      remove :image_preview
    end

    alter table(:comics) do
      add(:image_preview_id, references(:comic_previews, type: :uuid, on_delete: :nilify_all))
    end

    create unique_index(:comic_previews, [:comic_id])
  end
end
