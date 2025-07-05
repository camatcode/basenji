defmodule Basenji.Factory.CollectionFactory do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      def collection_factory(attrs) do
        parent_fn =
          fn ->
            if !Map.has_key?(attrs, :parent) && Enum.random([true, false]) do
              parent = insert(:collection)
              parent_comics = insert_list(Enum.random(1..10), :collection_comic, collection_id: parent.id)
              parent
            end
          end

        resource_dir = Basenji.Application.get_comics_directory()

        files = Path.wildcard("#{resource_dir}/**/cb*")

        resource_location =
          Map.get(
            attrs,
            :resource_location,
            if Enum.random([true, false]) do
              Enum.random(files)
            end
          )

        %Basenji.Collection{
          title: Faker.Lorem.sentence(),
          description: Faker.Lorem.paragraph(2),
          parent: parent_fn,
          resource_location: resource_location
        }
        |> merge_attributes(attrs)
        |> evaluate_lazy_attributes()
      end

      def collection_comic_factory(attrs) do
        %Basenji.CollectionComic{
          collection_id: fn -> insert(:collection) |> Map.get(:id) end,
          comic_id: fn -> insert(:comic) |> Map.get(:id) end
        }
        |> merge_attributes(attrs)
        |> evaluate_lazy_attributes()
      end
    end
  end
end
