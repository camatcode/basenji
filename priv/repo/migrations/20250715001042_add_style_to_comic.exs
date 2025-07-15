defmodule Basenji.Repo.Migrations.AddStyleToComic do
  use Ecto.Migration

  def change do
    alter table(:comics) do
      add :style, :integer
    end
  end
end
