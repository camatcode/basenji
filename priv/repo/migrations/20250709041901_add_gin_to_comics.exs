defmodule Basenji.Repo.Migrations.AddGinToComics do
  use Ecto.Migration

  def up do
    execute "CREATE INDEX comics_title_gin_idx ON comics USING gin(title gin_trgm_ops)"
    execute "CREATE INDEX comics_author_gin_idx ON comics USING gin(author gin_trgm_ops)"

    execute "CREATE INDEX comics_description_gin_idx ON comics USING gin(description gin_trgm_ops)"

    execute """
    CREATE INDEX comics_fulltext_gin_idx ON comics 
    USING gin((title || ' ' || COALESCE(author, '') || ' ' || COALESCE(description, '')) gin_trgm_ops)
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS comics_title_gin_idx"
    execute "DROP INDEX IF EXISTS comics_author_gin_idx"
    execute "DROP INDEX IF EXISTS comics_description_gin_idx"
    execute "DROP INDEX IF EXISTS comics_fulltext_gin_idx"
  end
end
