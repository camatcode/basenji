defmodule Basenji.Repo.Migrations.AddComics do
  use Ecto.Migration

  def change do
    create table(:comics, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :title, :string
      add :author, :string
      add :description, :text
      add :resource_location, :string
      add :released_year, :integer
      add :page_count, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
