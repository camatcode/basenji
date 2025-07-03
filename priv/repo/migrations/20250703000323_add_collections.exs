defmodule Basenji.Repo.Migrations.AddCollections do
  use Ecto.Migration

  def change do
    create table(:collections, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :title, :string
      add :description, :text

      add :parent_id, references(:collections, type: :uuid, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end
  end
end
