defmodule Basenji.ComicsTest do
  use Basenji.DataCase

  alias Basenji.Comics

  test "list_comics/1" do
    expected_count = 100
    asserted = insert_list(expected_count, :comic)
    retrieved = Comics.list_comics()
    assert Enum.count(retrieved) == expected_count

    Enum.each(asserted, fn comic ->
      assert [^comic] = Enum.filter(retrieved, &(&1.id == comic.id))
      assert comic.title
      assert comic.description
      assert comic.author
      assert comic.resource_location
      assert comic.released_year > 0
      assert comic.page_count > 0
    end)
  end
end
