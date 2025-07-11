defmodule BasenjiWeb.GraphQL.ComicsResolver do
  @moduledoc false
  alias Basenji.Comics

  def list_comics(_root, args, _info) do
    opts = Map.to_list(args)

    comics =
      Comics.list_comics(opts)
      |> set_image_preview()
      |> set_pages()

    {:ok, comics}
  end

  def create_comic(_root, %{input: attrs}, _info) do
    with {:ok, comic} <- Comics.create_comic(attrs) do
      comic
      |> set_image_preview()
      |> set_pages()
      |> then(&{:ok, &1})
    end
  end

  def get_comic(_root, %{id: id} = args, _info) do
    opts = Map.to_list(args)

    with {:ok, comic} <- Comics.get_comic(id, opts) do
      comic
      |> set_image_preview()
      |> set_pages()
      |> then(&{:ok, &1})
    end
  end

  def update_comic(_root, %{id: id, input: attrs}, _info) do
    with {:ok, comic} <- Comics.update_comic(id, attrs) do
      comic
      |> set_image_preview()
      |> set_pages()
      |> then(&{:ok, &1})
    end
  end

  def delete_comic(_root, %{id: id}, _info) do
    Comics.delete_comic(id)
  end

  def formats, do: Comics.formats()

  def order_by_attrs, do: Comics.attrs() -- [:image_preview]

  defp set_pages(comics) when is_list(comics) do
    comics
    |> Enum.map(&set_pages/1)
  end

  defp set_pages(%{page_count: page_count} = comic) when page_count <= 0, do: comic

  defp set_pages(%{page_count: page_count} = comic) do
    pages = 1..page_count |> Enum.map(fn page_num -> "/api/comics/#{comic.id}/page/#{page_num}" end)

    comic
    |> Map.put(:pages, pages)
  end

  defp set_image_preview(comics) when is_list(comics) do
    comics
    |> Enum.map(&set_image_preview/1)
  end

  defp set_image_preview(%{image_preview: nil} = comic), do: comic

  defp set_image_preview(comic) do
    comic
    |> Map.from_struct()
    |> Map.put(:image_preview, "/api/comics/#{comic.id}/preview")
  end
end
