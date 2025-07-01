defmodule Basenji.Comics do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Basenji.Comic
  alias Basenji.Repo

  def list_comics(opts \\ []) do
    opts = Keyword.merge([repo_opts: []], opts)

    Comic
    |> reduce_opts(opts)
    |> Repo.all(opts[:repo_opts])
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
