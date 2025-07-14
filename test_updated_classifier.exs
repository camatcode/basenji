#!/usr/bin/env elixir

# Test script for the updated classifier
# This will run a subset of items and compare with previous results

Mix.install([
  {:image, "~> 0.54.4"},
  {:vix, "~> 0.31.0"}
])

defmodule UpdatedClassifierTest do
  @moduledoc """
  Test the updated classifier on a sample set and analyze improvements
  """

  alias Basenji.Comics
  alias Basenji.Comics.Classifier
  alias Basenji.Comics.Comic

  def run_test(sample_size \\ 100) do
    IO.puts("=== TESTING UPDATED CLASSIFIER ===")
    IO.puts("Changes made:")
    IO.puts("- Final score threshold: 0.6 → 0.7")
    IO.puts("- Criteria required: 5/6 → 6/6")
    IO.puts("- Sample more pages (4-6 instead of 3)")
    IO.puts("- Start from page 3 instead of page 2")
    IO.puts("- Added comic feature detection (panel borders, aspect ratio)")
    IO.puts("")

    # Get a sample of comics and ebooks
    {:ok, comics} = get_test_sample(:comic, div(sample_size, 2))
    {:ok, ebooks} = get_test_sample(:ebook, div(sample_size, 2))

    IO.puts("Testing #{length(comics)} comics and #{length(ebooks)} ebooks...")
    IO.puts("")

    # Test comics
    IO.puts("=== TESTING COMICS ===")
    comic_results = test_items(comics, :comic)

    IO.puts("=== TESTING EBOOKS ===")
    ebook_results = test_items(ebooks, :ebook)

    # Summary
    IO.puts("")
    IO.puts("=== SUMMARY ===")

    comic_correct = Enum.count(comic_results, fn {_, _, predicted} -> predicted == :comic end)
    comic_total = length(comic_results)
    comic_accuracy = comic_correct / comic_total * 100

    ebook_correct = Enum.count(ebook_results, fn {_, _, predicted} -> predicted == :ebook end)
    ebook_total = length(ebook_results)
    ebook_accuracy = ebook_correct / ebook_total * 100

    overall_accuracy = (comic_correct + ebook_correct) / (comic_total + ebook_total) * 100

    IO.puts("Comic accuracy: #{comic_correct}/#{comic_total} (#{Float.round(comic_accuracy, 1)}%)")
    IO.puts("Ebook accuracy: #{ebook_correct}/#{ebook_total} (#{Float.round(ebook_accuracy, 1)}%)")
    IO.puts("Overall accuracy: #{Float.round(overall_accuracy, 1)}%")

    # Show misclassifications
    show_misclassifications(comic_results, :comic)
    show_misclassifications(ebook_results, :ebook)

    {:ok,
     %{
       comic_accuracy: comic_accuracy,
       ebook_accuracy: ebook_accuracy,
       overall_accuracy: overall_accuracy,
       comic_results: comic_results,
       ebook_results: ebook_results
     }}
  end

  defp get_test_sample(type, count) do
    # Get items from the database
    query =
      case type do
        :comic ->
          from c in Comic,
            where: c.page_count > 5,
            order_by: fragment("RANDOM()"),
            limit: ^count

        :ebook ->
          from c in Comic,
            # Ebooks tend to be longer
            where: c.page_count > 20,
            order_by: fragment("RANDOM()"),
            limit: ^count
      end

    items = Basenji.Repo.all(query)
    {:ok, items}
  end

  defp test_items(items, expected_type) do
    items
    |> Enum.map(fn item ->
      case Classifier.classify_comic(item.id) do
        {:ok, predicted_type} ->
          status = if predicted_type == expected_type, do: "✅", else: "❌"
          IO.puts("#{status} #{item.title} (#{item.page_count} pages) → #{predicted_type}")
          {item, expected_type, predicted_type}

        {:error, reason} ->
          IO.puts("❌ #{item.title} → ERROR: #{inspect(reason)}")
          {item, expected_type, :error}
      end
    end)
  end

  defp show_misclassifications(results, expected_type) do
    misclassified =
      Enum.filter(results, fn {_, expected, predicted} ->
        predicted != expected and predicted != :error
      end)

    if not Enum.empty?(misclassified) do
      opposite_type = if expected_type == :comic, do: :ebook, else: :comic
      IO.puts("")

      IO.puts(
        "❌ #{String.upcase(to_string(expected_type))}S MISCLASSIFIED AS #{String.upcase(to_string(opposite_type))}S:"
      )

      Enum.each(misclassified, fn {item, _, _} ->
        IO.puts("   - #{item.title} (#{item.page_count} pages)")
      end)
    end
  end
end

# Run the test
case UpdatedClassifierTest.run_test(50) do
  {:ok, results} ->
    IO.puts("")
    IO.puts("Test completed successfully!")

  {:error, reason} ->
    IO.puts("Test failed: #{inspect(reason)}")
end
