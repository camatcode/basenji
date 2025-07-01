defmodule Basenji.Factory.ComicFactory do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      def comic_factory(attrs) do
        %Basenji.Comic{
          title: Faker.Lorem.sentence(),
          author: Faker.Person.name(),
          description: Faker.Lorem.paragraph(2),
          resource_location: Faker.App.name() <> Enum.random([".cbz", ".cbt", ".cb7", ".cbr"]),
          released_year: Faker.Date.date_of_birth(1..20).year,
          page_count: Enum.random(1..1000)
        }
        |> merge_attributes(attrs)
        |> evaluate_lazy_attributes()
      end
    end
  end
end
