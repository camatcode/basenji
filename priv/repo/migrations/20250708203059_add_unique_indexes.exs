defmodule Basenji.Repo.Migrations.AddUniqueIndexes do
  use Ecto.Migration

  def change do
    create unique_index(:comics, [:resource_location])
    create unique_index(:collections, [:title])
  end
end
