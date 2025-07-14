defmodule Mix.Tasks.Basenji.ClassifyComics do
  @shortdoc "Test comic classification on sample data"
  @moduledoc """
  Test the comic classifier on your dataset.

  Usage:
    mix basenji.classify_comics               # Test on first 20 comics
    mix basenji.classify_comics --limit 100   # Test on first 100 comics
    mix basenji.classify_comics --all         # Test on all comics (careful!)
  """

  use Mix.Task

  alias Basenji.Comics
  alias Basenji.Comics.Classifier

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [limit: :integer, all: :boolean],
        aliases: [l: :limit, a: :all]
      )

    limit =
      cond do
        opts[:all] -> :all
        opts[:limit] -> opts[:limit]
        true -> 20
      end

    IO.puts("🔍 Starting comic classification test...")
    IO.puts("Limit: #{limit}")
    IO.puts("")

    comic_ids = get_comic_ids(limit)

    IO.puts("📚 Found #{length(comic_ids)} comics to analyze")
    IO.puts("⏱️  Starting batch classification...")
    IO.puts("")

    start_time = System.monotonic_time(:millisecond)

    results = Classifier.batch_classify(comic_ids, max_concurrency: 3)

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Process results
    {successes, errors} =
      Enum.split_with(results, fn
        {:ok, _, _} -> true
        _ -> false
      end)

    # Group by classification
    classifications = Enum.group_by(successes, fn {:ok, _, type} -> type end)

    comics_count = length(Map.get(classifications, :comic, []))
    ebooks_count = length(Map.get(classifications, :ebook, []))
    errors_count = length(errors)

    # Print summary
    IO.puts("✅ Classification Complete!")
    IO.puts("⏱️  Duration: #{duration}ms (#{Float.round(duration / length(comic_ids), 1)}ms per comic)")
    IO.puts("")
    IO.puts("📊 Results:")
    IO.puts("   Comics:  #{comics_count}")
    IO.puts("   Ebooks:  #{ebooks_count}")
    IO.puts("   Errors:  #{errors_count}")
    IO.puts("")

    if errors_count > 0 do
      IO.puts("❌ Errors:")

      Enum.each(errors, fn {:error, comic_id, reason} ->
        IO.puts("   Comic #{comic_id}: #{inspect(reason)}")
      end)

      IO.puts("")
    end

    # Show some sample results
    IO.puts("📋 Sample Results:")

    successes
    |> Enum.take(10)
    |> Enum.each(fn {:ok, comic_id, classification} ->
      {:ok, comic} = Comics.get_comic(comic_id)
      IO.puts("   #{comic.title || "Untitled"} (#{comic_id}): #{classification}")
    end)

    if length(successes) > 10 do
      IO.puts("   ... and #{length(successes) - 10} more")
    end
  end

  defp get_comic_ids(:all) do
    Comics.list_comics() |> Enum.map(& &1.id)
  end

  defp get_comic_ids(limit) do
    Comics.list_comics(limit: limit) |> Enum.map(& &1.id)
  end
end
