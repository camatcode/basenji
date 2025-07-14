defmodule Basenji.Comics.ClassifierTest do
  @moduledoc """
  Comprehensive test runner for the comic/ebook classifier analysis.
  """

  alias Basenji.Comics
  alias Basenji.Comics.Classifier
  alias Basenji.Comics.ClassifierReport

  @doc """
  Run a quick test on a limited number of items.
  """
  def quick_test(limit \\ 20) do
    IO.puts("🧪 Running quick test on #{limit} items...")

    ClassifierReport.run_full_analysis(
      output_file: "quick_test_report.txt",
      limit: limit,
      include_criteria_details: true
    )
  end

  @doc """
  Run the full comprehensive analysis on ALL your comics and ebooks.
  This will take a while but give you complete insights.
  """
  def full_analysis do
    IO.puts("🔍 Running FULL analysis on ALL comics and ebooks...")
    IO.puts("⚠️  This will take a while depending on your collection size!")

    ClassifierReport.run_full_analysis(
      output_file: "full_classifier_report.txt",
      include_criteria_details: true
    )
  end

  @doc """
  Run analysis without detailed criteria breakdown (faster).
  """
  def fast_analysis(limit \\ nil) do
    IO.puts("⚡ Running fast analysis...")

    ClassifierReport.run_full_analysis(
      output_file: "fast_report.txt",
      limit: limit,
      include_criteria_details: false
    )
  end

  @doc """
  Analyze only ebooks to focus on ebook classification accuracy.
  """
  def ebook_only_test(limit \\ nil) do
    IO.puts("📖 Testing ebook classification only...")

    # Get only ebooks
    all_comics =
      if limit do
        # Get more to find enough ebooks
        Basenji.Comics.list_comics(limit: limit * 2)
      else
        Basenji.Comics.list_comics()
      end

    ebooks =
      Enum.filter(all_comics, fn comic ->
        String.contains?(comic.resource_location, "ebook") &&
          !String.contains?(comic.resource_location, "mag")
      end)

    ebooks_to_test = if limit, do: Enum.take(ebooks, limit), else: ebooks

    IO.puts("📊 Found #{length(ebooks_to_test)} ebooks to test")

    ClassifierReport.run_full_analysis(
      output_file: "ebook_test_report.txt",
      limit: length(ebooks_to_test),
      include_criteria_details: true
    )
  end

  # Legacy test functions (kept for backwards compatibility)
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
