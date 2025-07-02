defmodule Basenji.Comics do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Basenji.Comic
  alias Basenji.Reader
  alias Basenji.Repo

  def load_from_directory(path) do
    path = Path.expand(path)

    Path.wildcard("#{path}/**/*.cb*")
    |> Enum.each(fn file ->
      from_resource(file) |> IO.inspect()
    end)
  end

  def from_resource(location, attrs \\ %{}, opts \\ []) do
    with {:ok, info} <- Reader.info(location) do
      Map.merge(info, attrs)
      |> create_comic(opts)
    end
  end

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
    |> case do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  def update_comic(%Comic{} = comic, attrs) do
    comic
    |> Comic.update_changeset(attrs)
    |> Repo.update()
  end

  def update_comic(id, attrs) when is_bitstring(id) do
    with {:ok, comic} <- get_comic(id) do
      update_comic(comic, attrs)
    end
  end

  def delete_comic(nil), do: nil

  def delete_comic(comic_id) when is_binary(comic_id) do
    %Comic{id: comic_id}
    |> delete_comic()
  end

  def delete_comic(%Comic{id: _comic_id} = comic) do
    Repo.delete(comic)
  end

  def stream_pages(ref, opts \\ [])

  def stream_pages(nil, _opts), do: {:error, :not_found}

  def stream_pages(%Comic{resource_location: loc}, opts) do
    opts = Keyword.merge([optimize: true], opts)
    Reader.stream_pages(loc, opts)
  end

  def stream_pages(comic_id, opts) when is_bitstring(comic_id) do
    with {:ok, comic} <- get_comic(comic_id) do
      stream_pages(comic, opts)
    end
  end

  def get_page(comic, page_num, opts \\ [])

  def get_page(nil, _, _), do: {:error, :not_found}

  def get_page(%Comic{page_count: page_count}, page_num, _opts) when page_num < 0 or page_num > page_count,
    do: {:error, :not_found}

  def get_page(%Comic{resource_location: loc} = _comic, page_num, opts) do
    opts = Keyword.merge([optimize: true], opts)

    with {:ok, %{entries: entries}} <- Reader.read(loc, opts) do
      entry = Enum.at(entries, page_num - 1)

      ext =
        Map.get(entry, :file_name)
        |> Path.extname()
        |> String.replace(".", "")

      {:ok, Enum.at(entries, page_num - 1).stream_fun.(), "image/#{ext}"}
    end
  end

  def get_page(comic_id, page_num, opts) when is_bitstring(comic_id) do
    with {:ok, comic} <- get_comic(comic_id) do
      get_page(comic, page_num, opts)
    end
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
