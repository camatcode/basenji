defmodule Basenji.Comics do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Basenji.Comic
  alias Basenji.Repo

  def create_comic(attrs, opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    %Comic{}
    |> Comic.changeset(attrs)
    |> Repo.insert(opts[:repo_opts])
  end

  def list_comics(opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    Comic
    |> reduce_opts(opts)
    |> Repo.all(opts[:repo_opts])
  end

  def get_comic(id, opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    from(c in Comic, where: c.id == ^id)
    |> reduce_opts(opts)
    |> reduce_comic_opts(opts)
    |> Repo.one(opts[:repo_opts])
  end

  def update_comic(%Comic{} = comic, attrs) do
    comic
    |> Comic.changeset(attrs)
    |> Repo.update()
  end

  def delete_comic(nil), do: nil

  def delete_comic(comic_id) when is_binary(comic_id) do
    %Comic{id: comic_id}
    |> delete_comic()
  end

  def delete_comic(%Comic{id: _comic_id} = comic) do
    Repo.delete(comic)
  end

  defp reduce_comic_opts(query, opts) do
    Enum.reduce(opts, query, fn
      {_any, ""}, query ->
        query

      _, query ->
        query
    end)
  end

  defp reduce_opts(query, opts) do
    Enum.reduce(opts, query, fn
      {_any, ""}, query ->
        query

      _, query ->
        query
    end)
  end
end
