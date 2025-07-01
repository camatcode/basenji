defmodule Basenji.ComicsTest do
  use Basenji.DataCase

  alias Basenji.Comics

  describe "crud" do
    test "create_comic/2" do
      to_assert = build_list(100, :comic)
      refute Enum.empty?(to_assert)

      Enum.each(to_assert, fn comic ->
        {:ok, created} =
          comic
          |> Map.from_struct()
          |> Comics.create_comic()

        assert created.id
        assert created.title == comic.title
      end)
    end

    test "from_resource" do
      Basenji.Comic.formats()
      |> Enum.each(fn format ->
        resource_dir = Basenji.Application.get_comics_directory()

        files = Path.wildcard("#{resource_dir}/**/*.#{format}")
        refute Enum.empty?(files)

        files
        |> Enum.each(fn file ->
          {:ok, comic} = Comics.from_resource(file)
          assert comic.title
          assert comic.page_count
          assert comic.resource_location
        end)
      end)
    end

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
        assert comic.format
      end)
    end

    test "get_comic/2" do
      asserted = insert_list(100, :comic)
      refute Enum.empty?(asserted)

      Enum.each(asserted, fn comic ->
        assert comic == Comics.get_comic(comic.id)
      end)
    end

    test "update_comic/2" do
      asserted = insert_list(100, :comic)
      refute Enum.empty?(asserted)

      Enum.each(asserted, fn comic ->
        updated_attrs = %{
          title: Faker.Lorem.sentence(),
          author: Faker.Person.name(),
          description: Faker.Lorem.paragraph(2),
          resource_location: Faker.App.name() <> ".cbz",
          released_year: Enum.random(2015..2025),
          page_count: Enum.random(1..1000)
        }

        {:ok, updated} = Comics.update_comic(comic, updated_attrs)
        assert updated.title == updated_attrs.title
        assert updated.author == updated_attrs.author
        assert updated.description == updated_attrs.description
        assert updated.resource_location == updated_attrs.resource_location
        assert updated.released_year == updated_attrs.released_year
        assert updated.page_count == updated_attrs.page_count
      end)
    end

    test "delete_comic/2" do
      to_delete = insert_list(100, :comic)
      refute Enum.empty?(to_delete)

      Enum.each(to_delete, fn comic ->
        # Either by ID or by struct
        ref = Enum.random([comic, comic.id])
        {:ok, deleted} = Comics.delete_comic(ref)
        assert comic.id == deleted.id
        refute Comics.get_comic(deleted.id)
      end)
    end
  end

  test "get_page" do
    comic = insert(:comic)

    1..comic.page_count
    |> Enum.each(fn page ->
      ref = Enum.random([comic, comic.id])
      {:ok, stream} = Comics.get_page(ref, page)
      bin_list = stream |> Enum.to_list()
      refute Enum.empty?(bin_list)
    end)

    # overflow
    {:error, :not_found} = Comics.get_page(comic, comic.page_count + 1)

    # underflow
    {:error, :not_found} = Comics.get_page(comic, -1)
  end

  test "stream_pages" do
    comic = insert(:comic)

    {:ok, stream} = Comics.stream_pages(comic)
    pages = stream |> Enum.to_list()
    assert Enum.count(pages) == comic.page_count

    Enum.each(pages, fn page_stream ->
      bin_list = page_stream |> Enum.to_list()
      refute Enum.empty?(bin_list)
    end)
  end
end
