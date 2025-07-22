defmodule Basenji.Repo.Migrations.AddHashToComic do
  use Ecto.Migration

  def change do
    alter table(:comics) do
      add :hash, :string
    end
  end
end
