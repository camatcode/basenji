defmodule Basenji.Repo.Migrations.ApiTokens do
  use Ecto.Migration

  def change do
    create table(:api_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
