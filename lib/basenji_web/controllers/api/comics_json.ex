defmodule BasenjiWeb.ComicsJSON do
  @moduledoc false


  def render("show.json", %{comic: comic}) do
    %{data: data(comic)}
  end

  def render("list.json", %{comics: comics}) do
    %{data: for(c <- comics, do: data(c))}
  end


  def data(comic) do
    %{
      id: comic.id,
      title: comic.title,
      author: comic.author,
      description: comic.description,
      resource_location: comic.resource_location,
      released_year: comic.released_year,
      page_count: comic.page_count,
      format: comic.format,
      inserted_at: comic.inserted_at,
      updated_at: comic.updated_at
    }
  end
end
