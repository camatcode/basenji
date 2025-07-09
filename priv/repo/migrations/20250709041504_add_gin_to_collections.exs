defmodule Basenji.Repo.Migrations.AddGinToCollections do
  use Ecto.Migration

  def up do
    execute "CREATE INDEX collections_title_gin_idx ON collections USING gin(title gin_trgm_ops)"
    execute "CREATE INDEX collections_description_gin_idx ON collections USING gin(description gin_trgm_ops)"

    execute """
    CREATE INDEX collections_fulltext_gin_idx ON collections
    USING gin((title || ' ' || COALESCE(description, '')) gin_trgm_ops)
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS collections_title_gin_idx"
    execute "DROP INDEX IF EXISTS collections_description_gin_idx"
    execute "DROP INDEX IF EXISTS collections_fulltext_gin_idx"
  end
end
