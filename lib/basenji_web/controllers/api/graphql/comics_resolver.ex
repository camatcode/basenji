defmodule BasenjiWeb.GraphQL.ComicsResolver do
  alias Basenji.Comics

  def list_comics(_root, _args, _info) do
    {:ok, Comics.list_comics()}
  end

  def get_comic(_root, %{id: id}, _info) do
    case Comics.get_comic(id) do
      {:ok, comic} -> {:ok, comic}
      {:error, :not_found} -> {:error, "Comic not found"}
    end
  end
end
