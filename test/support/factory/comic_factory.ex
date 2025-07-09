defmodule Basenji.Factory.ComicFactory do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case

      defp make_resource_location(%{resource_location: rec_loc}, format) when is_bitstring(rec_loc) do
        {:ok, %{entries: entries}} = Basenji.Reader.read(rec_loc)
        page_count = Enum.count(entries)
        {rec_loc, page_count}
      end

      defp make_resource_location(_attrs, format) do
        resource_dir = Basenji.Application.get_comics_directory()

        files = Path.wildcard("#{resource_dir}/**/*.#{format}")
        random_file = Enum.random(files)

        tmp = Path.join(System.tmp_dir!(), Path.dirname(random_file) <> "#{System.monotonic_time()}")
        File.mkdir_p!(tmp)
        rec_loc = Path.join(tmp, Path.basename(random_file))
        File.cp!(random_file, rec_loc)
        on_exit(fn -> File.rm_rf!(tmp) end)

        {:ok, %{entries: entries}} = Basenji.Reader.read(rec_loc)
        page_count = Enum.count(entries)

        {rec_loc, page_count}
      end

      def comic_factory(attrs) do
        format = Map.get(attrs, :format, Enum.random(Basenji.Comic.formats()))

        {resource_location, page_count} = make_resource_location(attrs, format)

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
