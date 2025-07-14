defmodule Basenji.Comics.ClassifierTest do
  @moduledoc """
  Quick test runner for the comic classifier.
  Use this to test the classifier on a few comics before running the full batch.
  """

  alias Basenji.Comics
  alias Basenji.Comics.Classifier

  def quick_test(count \\ 3) do
    IO.puts("🔍 Testing classifier on #{count} comics...")

    Comics.list_comics(limit: count)
    |> Enum.each(&test_single_comic/1)
  end

  def test_single_comic(comic) do
    IO.puts("\n📚 Testing: #{comic.title || "Untitled"} (ID: #{comic.id})")
    IO.puts("   Format: #{comic.format}, Pages: #{comic.page_count}")

    start_time = System.monotonic_time(:millisecond)

    case Classifier.classify_comic(comic.id) do
      {:ok, classification} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        IO.puts("   ✅ Result: #{classification} (#{duration}ms)")

      {:error, reason} ->
        IO.puts("   ❌ Error: #{inspect(reason)}")
    end
  end

  def test_page_extraction(comic_id, page_num \\ 1) do
    IO.puts("🔍 Testing page extraction...")

    with {:ok, comic} <- Comics.get_comic(comic_id) do
      IO.puts("Comic: #{comic.title || "Untitled"}")

      case Comics.get_page(comic, page_num) do
        {:ok, page_data} ->
          IO.puts("✅ Successfully extracted page #{page_num}")
          IO.puts("   Data size: #{byte_size(page_data)} bytes")

          # Test temp file creation
          temp_path = Path.join([System.tmp_dir(), "test_page.jpg"])
          File.write!(temp_path, page_data)

          # Test image loading
          case Image.open(temp_path) do
            {:ok, image} ->
              {width, height, _bands} = Image.shape(image)
              IO.puts("   ✅ Image loaded: #{width}x#{height}")

            {:error, reason} ->
              IO.puts("   ❌ Image load failed: #{inspect(reason)}")
          end

          File.rm(temp_path)

        {:error, reason} ->
          IO.puts("❌ Failed to extract page: #{inspect(reason)}")
      end
    end
  end
end
