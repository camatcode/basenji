defmodule Basenji.Repo.Migrations.AddPreviewToComics do
  use Ecto.Migration

  def change do
    alter table(:comics) do
      add :image_preview, :binary
    end
  end
end
