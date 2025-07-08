defmodule Basenji.Repo.Migrations.AddByteSizeToComics do
  use Ecto.Migration

  def change do
    alter table(:comics) do
      add :byte_size, :integer
    end
  end
end
