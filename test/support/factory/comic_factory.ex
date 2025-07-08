defmodule Basenji.Factory.ComicFactory do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      def comic_factory(attrs) do
        format = Map.get(attrs, :format, Enum.random(Basenji.Comic.formats()))

        resource_dir = Basenji.Application.get_comics_directory()

        files = Path.wildcard("#{resource_dir}/**/*.#{format}")

        resource_location =
          Map.get(attrs, :resource_location, Enum.random(files))

        page_count =
          Map.get(attrs, :page_count, fn ->
            if String.starts_with?(resource_location, resource_dir) do
              {:ok, %{entries: entries}} = Basenji.Reader.read(resource_location)
              Enum.count(entries)
            else
              Enum.random(1..1000)
            end
          end)

        %Basenji.Comic{
          title: Faker.Lorem.sentence(),
          author: Faker.Person.name(),
          description: Faker.Lorem.paragraph(2),
          format: format,
          resource_location: resource_location,
          released_year: Faker.Date.date_of_birth(1..20).year,
          page_count: page_count
        }
        |> merge_attributes(attrs)
        |> evaluate_lazy_attributes()
        |> Basenji.Comic.changeset(%{})
        |> Ecto.Changeset.apply_action!(:validate)
      end
    end
  end
end
