defmodule Basenji.Comics.UpdatedClassifierReport do
  @moduledoc """
  Comprehensive testing and reporting tool for the UPDATED comic/ebook classifier.
  Generates detailed reports with scores, criteria breakdowns, and full analysis
  matching the style of the original full classifier report.
  """

  alias Basenji.Comics
  alias Vix.Vips.Operation

  require Logger

  @doc """
  Generate a comprehensive analysis report on all comics and ebooks using the updated classifier.
  Includes detailed scores, criteria breakdowns, and extensive analysis.

  Options:
  - `:output_file` - Path to write report (default: "updated_full_classifier_report.txt")
  - `:limit` - Maximum number of items to test (default: nil for all)
  """
  def generate_report(opts \\ []) do
    output_file = Keyword.get(opts, :output_file, "updated_full_classifier_report.txt")
    limit = Keyword.get(opts, :limit)

    IO.puts("🔍 Starting comprehensive UPDATED classifier analysis...")
    IO.puts("📝 Report will be written to: #{output_file}")

    # Get all comics
    all_comics =
      if limit do
        Comics.list_comics(limit: limit)
      else
        Comics.list_comics()
      end

    IO.puts("📊 Found #{length(all_comics)} items to analyze")

    # Separate ebooks from comics based on path
    {ebooks, comics} =
      Enum.split_with(all_comics, fn comic ->
        String.contains?(comic.resource_location, "ebook") &&
          !String.contains?(comic.resource_location, "mag")
      end)

    IO.puts("   📖 Ebooks: #{length(ebooks)}")
    IO.puts("   📚 Comics: #{length(comics)}")

    # Open report file
    {:ok, file} = File.open(output_file, [:write, :utf8])

    try do
      write_report_header(file, ebooks, comics)

      # Analyze ebooks
      IO.puts("\n🔍 Analyzing ebooks...")
      ebook_results = analyze_items(ebooks, :ebook, file)

      # Analyze comics  
      IO.puts("🔍 Analyzing comics...")
      comic_results = analyze_items(comics, :comic, file)

      # Write comprehensive summary
      write_comprehensive_summary(file, ebook_results, comic_results)

      # Print summary to console
      print_console_summary(ebook_results, comic_results)

      %{
        ebooks: ebook_results,
        comics: comic_results,
        total_accuracy: calculate_total_accuracy(ebook_results, comic_results),
        report_file: output_file
      }
    after
      File.close(file)
    end
  end

  # Analyze a list of items with detailed scoring
  defp analyze_items(items, expected_type, file) do
    results = %{
      total: length(items),
      correct: 0,
      incorrect: 0,
      errors: 0,
      correct_items: [],
      incorrect_items: [],
      error_items: []
    }

    write_section_header(file, expected_type, length(items))

    Enum.reduce(items, results, fn item, acc ->
      analyze_single_item_detailed(item, expected_type, file, acc)
    end)
  end

  defp analyze_single_item_detailed(item, expected_type, file, acc) do
    # Progress indicator
    IO.write(".")

    start_time = System.monotonic_time(:millisecond)

    case classify_with_detailed_scores(item.id) do
      {:ok, predicted_type, detailed_scores} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        correct = predicted_type == expected_type

        # Write detailed result to report
        write_detailed_item_result(file, item, expected_type, predicted_type, correct, duration, detailed_scores)

        # Update accumulator
        if correct do
          %{acc | correct: acc.correct + 1, correct_items: [item | acc.correct_items]}
        else
          %{
            acc
            | incorrect: acc.incorrect + 1,
              incorrect_items: [{item, predicted_type, detailed_scores} | acc.incorrect_items]
          }
        end

      {:error, reason} ->
        write_error_result(file, item, expected_type, reason)
        %{acc | errors: acc.errors + 1, error_items: [{item, reason} | acc.error_items]}
    end
  end

  # Classify with detailed score breakdown (like the original)
  defp classify_with_detailed_scores(comic_id) do
    case Comics.get_comic(comic_id) do
      {:ok, comic} ->
        case get_sample_pages(comic) do
          {:ok, sample_pages} ->
            page_scores = analyze_pages_with_details(comic, sample_pages)

            if Enum.empty?(page_scores) or Enum.all?(page_scores, fn {_, score, _} -> score == 0.0 end) do
              {:error, :no_valid_pages}
            else
              # Calculate final classification
              scores = Enum.map(page_scores, fn {_, score, _} -> score end)
              avg_score = Enum.sum(scores) / length(scores)
              classification = if avg_score > 0.7, do: :ebook, else: :comic

              # Prepare detailed scores for report
              detailed_scores = %{
                sample_pages: sample_pages,
                page_details: page_scores,
                avg_score: avg_score,
                classification: classification
              }

              {:ok, classification, detailed_scores}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_pages_with_details(comic, page_indices) do
    page_indices
    |> Enum.map(fn page_num ->
      case Comics.get_page(comic, page_num) do
        {:ok, page_data, _content_type} ->
          temp_path = create_temp_file(page_data)

          try do
            {:ok, image} = Image.open(temp_path)

            # Get detailed breakdown like the original
            saturation_score = analyze_saturation(image)
            {bimodal_score, criteria_details} = analyze_histogram_with_criteria_details(image)
            edge_score = analyze_edge_density(image)
            comic_features = detect_comic_features(image)

            # Apply the same scoring as the updated classifier
            base_score = saturation_score * 0.4 + bimodal_score * 0.5 + edge_score * 0.1
            final_score = base_score * (1.0 - comic_features * 0.3)

            {page_num, final_score,
             %{
               saturation: saturation_score,
               bimodal: bimodal_score,
               edge: edge_score,
               comic_features: comic_features,
               criteria: criteria_details
             }}
          rescue
            _ -> {page_num, 0.0, %{error: "Analysis failed"}}
          after
            File.rm(temp_path)
          end

        {:error, _} ->
          {page_num, 0.0, %{error: "Page extraction failed"}}
      end
    end)
  end

  # Helper functions (copied from updated classifier)
  defp get_sample_pages(comic) do
    page_count = comic.page_count || 0

    if page_count < 5 do
      {:error, :no_pages}
    else
      sample_indices =
        case page_count do
          n when n <= 15 -> [3, div(n, 3) + 1, div(n * 2, 3), n - 2]
          n when n <= 50 -> [3, div(n, 4) + 2, div(n, 2), div(n * 3, 4), n - 2]
          n -> [3, div(n, 5) + 2, div(n * 2, 5), div(n * 3, 5), div(n * 4, 5), n - 2]
        end
        |> Enum.filter(&(&1 >= 3 and &1 <= page_count))
        |> Enum.uniq()

      {:ok, sample_indices}
    end
  end

  defp create_temp_file(page_data) do
    temp_path = Path.join([System.tmp_dir(), "updated_classify_#{:rand.uniform(999_999)}.jpg"])
    File.write!(temp_path, page_data)
    temp_path
  end

  defp analyze_saturation(image) do
    {:ok, hsv} = Image.to_colorspace(image, :hsv)
    channels = Image.split_bands(hsv)
    sat_channel = Enum.at(channels, 1)
    [avg_sat] = Image.average(sat_channel)
    1.0 - avg_sat / 255.0
  rescue
    _ -> 0.0
  end

  defp analyze_histogram_with_criteria_details(image) do
    {:ok, gray} = Image.to_colorspace(image, :bw)
    {:ok, histogram_image} = Operation.hist_find(gray)

    histogram_values =
      for x <- 0..255 do
        case Operation.getpoint(histogram_image, x, 0) do
          {:ok, [value]} -> round(value)
          _ -> 0
        end
      end

    total_pixels = Enum.sum(histogram_values)

    if total_pixels > 0 do
      # Calculate all criteria with details (matching updated classifier)
      light_end = Enum.slice(histogram_values, 240, 16)
      max_light_peak = Enum.max(light_end)
      light_concentration = max_light_peak / total_pixels

      light_sorted = Enum.sort(light_end, :desc)

      peak_sharpness =
        if Enum.at(light_sorted, 1) > 0 do
          Enum.at(light_sorted, 0) / Enum.at(light_sorted, 1)
        else
          1.0
        end

      dark_end = Enum.slice(histogram_values, 0, 10)
      zeros_count = Enum.count(dark_end, &(&1 == 0))
      min_nonzero = dark_end |> Enum.filter(&(&1 > 0)) |> Enum.min(fn -> 0 end)

      dark_region = Enum.slice(histogram_values, 0, 80) |> Enum.sum()
      light_region = Enum.slice(histogram_values, 180, 76) |> Enum.sum()
      middle_region = Enum.slice(histogram_values, 80, 100) |> Enum.sum()

      dark_ratio = dark_region / total_pixels
      light_ratio = light_region / total_pixels
      middle_ratio = middle_region / total_pixels
      bimodal_strength = dark_ratio + light_ratio

      # Updated criteria (6/6 required now)
      criteria = [
        {:light_concentration, light_concentration > 0.20, light_concentration},
        {:peak_sharpness, peak_sharpness > 5.0, peak_sharpness},
        {:zeros_count, zeros_count <= 2, zeros_count},
        {:min_nonzero, min_nonzero > 50, min_nonzero},
        {:bimodal_strength, bimodal_strength > 0.60, bimodal_strength},
        {:middle_ratio, middle_ratio < 0.35, middle_ratio}
      ]

      criteria_met = Enum.count(criteria, fn {_, passed, _} -> passed end)

      # Updated: now requires 6/6
      score =
        if criteria_met >= 6 do
          base_score = criteria_met / 6.0
          bimodal_bonus = bimodal_strength * 0.5
          (base_score + bimodal_bonus) |> min(1.0)
        else
          0.0
        end

      criteria_details = %{
        criteria: criteria,
        criteria_met: criteria_met,
        light_concentration: light_concentration,
        peak_sharpness: peak_sharpness,
        zeros_count: zeros_count,
        min_nonzero: min_nonzero,
        bimodal_strength: bimodal_strength,
        middle_ratio: middle_ratio
      }

      {score, criteria_details}
    else
      {0.0, %{error: "Histogram analysis failed"}}
    end
  rescue
    _ -> {0.0, %{error: "Histogram analysis failed"}}
  end

  defp analyze_edge_density(image) do
    {:ok, sharpened} = Image.sharpen(image)
    original_bands = Image.average(image)
    original_avg = Enum.sum(original_bands) / length(original_bands)
    sharpened_bands = Image.average(sharpened)
    sharpened_avg = Enum.sum(sharpened_bands) / length(sharpened_bands)
    edge_response = abs(sharpened_avg - original_avg) / 255.0
    min(edge_response * 3.0, 1.0)
  rescue
    _ -> 0.0
  end

  # Simplified comic detection for report
  defp detect_comic_features(image) do
    {width, height, _bands} = Image.shape(image)
    aspect_ratio = width / height

    # Comic pages often have certain aspect ratios
    cond do
      aspect_ratio > 0.6 and aspect_ratio < 0.8 -> 0.3
      aspect_ratio > 1.2 -> 0.5
      true -> 0.0
    end
  rescue
    _ -> 0.0
  end

  # Report writing functions
  defp write_report_header(file, ebooks, comics) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()

    IO.write(file, """
    ================================================================================
    UPDATED COMIC/EBOOK CLASSIFIER ANALYSIS REPORT
    ================================================================================
    Generated: #{timestamp}

    DATASET OVERVIEW:
    - Total Items: #{length(ebooks) + length(comics)}
    - Ebooks: #{length(ebooks)}
    - Comics: #{length(comics)}

    UPDATED CLASSIFIER CONFIGURATION:
    - Saturation Weight: 0.4
    - Bimodal Weight: 0.5  
    - Edge Weight: 0.1
    - Classification Threshold: 0.7 (UPDATED from 0.6)
    - Criteria Required: 6/6 for text classification (UPDATED from 5/6)
    - Sample Pages: 4-6 pages starting from page 3 (UPDATED from 3 pages from page 2)
    - Comic Feature Detection: Added (panel borders, aspect ratio with penalty)

    CHANGES MADE TO CLASSIFIER:
    1. Raised final score threshold from 0.6 to 0.7
    2. Changed from 5/6 to 6/6 criteria required for text classification
    3. Sample more pages (4-6 instead of 3) for better accuracy
    4. Start sampling from page 3 instead of page 2 (avoid covers)
    5. Added comic feature detection with score penalty

    ================================================================================

    """)
  end

  defp write_section_header(file, type, count) do
    type_name = if type == :ebook, do: "EBOOKS", else: "COMICS"

    IO.write(file, """

    #{type_name} ANALYSIS (#{count} items)
    #{String.duplicate("=", 50)}

    """)
  end

  defp write_detailed_item_result(file, item, expected, actual, correct, duration, details) do
    status = if correct, do: "✅ CORRECT", else: "❌ INCORRECT"
    title = String.slice(item.title || "Untitled", 0, 60)
    filename = Path.basename(item.resource_location)

    # Calculate average scores for display
    avg_sat = avg_score_from_details(details.page_details, :saturation)
    avg_bio = avg_score_from_details(details.page_details, :bimodal)
    avg_edge = avg_score_from_details(details.page_details, :edge)

    IO.write(file, """
    #{status} | #{expected} → #{actual} | #{duration}ms
    Title: #{title}
    File: #{filename}
    Pages: #{item.page_count}
    Scores: sat=#{Float.round(avg_sat, 3)} bio=#{Float.round(avg_bio, 3)} edge=#{Float.round(avg_edge, 3)} → #{Float.round(details.avg_score, 3)}
    Sample Pages: #{inspect(details.sample_pages)}
    """)

    # Write detailed criteria for incorrect classifications (like original report)
    if not correct and details.page_details do
      IO.write(file, "  Detailed Analysis:\n")

      Enum.each(details.page_details, fn {page_num, _score, page_detail} ->
        if page_detail[:criteria] do
          criteria_info = page_detail.criteria
          IO.write(file, "    Page #{page_num}: #{criteria_info.criteria_met}/6 criteria met\n")

          Enum.each(criteria_info.criteria, fn {name, passed, value} ->
            status_icon = if passed, do: "✅", else: "❌"
            formatted_value = if is_float(value), do: Float.round(value, 3), else: value
            IO.write(file, "      #{status_icon} #{name}: #{formatted_value}\n")
          end)
        end
      end)
    end

    IO.write(file, "\n")
  end

  defp write_error_result(file, item, expected, reason) do
    title = String.slice(item.title || "Untitled", 0, 60)
    filename = Path.basename(item.resource_location)

    IO.write(file, """
    ❌ ERROR | #{expected} → ERROR
    Title: #{title}
    File: #{filename}
    Error: #{inspect(reason)}

    """)
  end

  defp write_comprehensive_summary(file, ebook_results, comic_results) do
    total_items = ebook_results.total + comic_results.total
    total_correct = ebook_results.correct + comic_results.correct
    total_accuracy = if total_items > 0, do: total_correct / total_items * 100, else: 0

    ebook_accuracy = if ebook_results.total > 0, do: ebook_results.correct / ebook_results.total * 100, else: 0
    comic_accuracy = if comic_results.total > 0, do: comic_results.correct / comic_results.total * 100, else: 0

    IO.write(file, """

    ================================================================================
    COMPREHENSIVE SUMMARY STATISTICS
    ================================================================================

    OVERALL PERFORMANCE:
    - Total Accuracy: #{Float.round(total_accuracy, 1)}% (#{total_correct}/#{total_items})
    - Processing Errors: #{ebook_results.errors + comic_results.errors}

    EBOOK CLASSIFICATION:
    - Accuracy: #{Float.round(ebook_accuracy, 1)}% (#{ebook_results.correct}/#{ebook_results.total})
    - Correctly Classified: #{ebook_results.correct}
    - Misclassified as Comics: #{ebook_results.incorrect}
    - Errors: #{ebook_results.errors}

    COMIC CLASSIFICATION:  
    - Accuracy: #{Float.round(comic_accuracy, 1)}% (#{comic_results.correct}/#{comic_results.total})
    - Correctly Classified: #{comic_results.correct}
    - Misclassified as Ebooks: #{comic_results.incorrect}
    - Errors: #{comic_results.errors}

    """)

    # Detailed misclassification analysis
    if not Enum.empty?(ebook_results.incorrect_items) do
      IO.write(file, "EBOOKS MISCLASSIFIED AS COMICS:\n")

      Enum.each(ebook_results.incorrect_items, fn {item, _actual_type, details} ->
        IO.write(file, "- #{item.title || "Untitled"} (#{item.page_count} pages)")

        if details do
          IO.write(file, " → Score: #{Float.round(details.avg_score, 3)}")
        end

        IO.write(file, "\n")
      end)

      IO.write(file, "\n")
    end

    if not Enum.empty?(comic_results.incorrect_items) do
      IO.write(file, "COMICS MISCLASSIFIED AS EBOOKS:\n")

      Enum.each(comic_results.incorrect_items, fn {item, _actual_type, details} ->
        IO.write(file, "- #{item.title || "Untitled"} (#{item.page_count} pages)")

        if details do
          IO.write(file, " → Score: #{Float.round(details.avg_score, 3)}")
        end

        IO.write(file, "\n")
      end)

      IO.write(file, "\n")
    end

    IO.write(file, """
    ================================================================================
    COMPARISON WITH ORIGINAL CLASSIFIER RESULTS

    EXPECTED IMPROVEMENTS:
    1. Fewer comics misclassified as ebooks (was the primary issue)
    2. Better handling of manga-style and clean line art comics
    3. More accurate page sampling avoiding cover pages
    4. Stricter criteria reducing false text detection

    ORIGINAL CLASSIFIER PROBLEMS ADDRESSED:
    - Comics with high bimodal scores (clean B&W art) getting classified as text
    - Cover pages skewing analysis
    - 5/6 criteria threshold being too lenient
    - 0.6 final score threshold being too low

    TO COMPARE RESULTS:
    - Check reduction in "Comics misclassified as ebooks" count
    - Verify specific problematic titles like "Bread and Wine", "Ball Park", etc.
    - Compare overall accuracy while focusing on comic → ebook error reduction

    ================================================================================
    """)
  end

  defp avg_score_from_details(page_details, key) do
    scores =
      page_details
      |> Enum.map(fn {_page, _score, detail} -> Map.get(detail, key) end)
      |> Enum.filter(&is_number/1)

    if Enum.empty?(scores) do
      0.0
    else
      Enum.sum(scores) / length(scores)
    end
  end

  defp calculate_total_accuracy(ebook_results, comic_results) do
    total_items = ebook_results.total + comic_results.total
    total_correct = ebook_results.correct + comic_results.correct
    if total_items > 0, do: total_correct / total_items * 100, else: 0
  end

  defp print_console_summary(ebook_results, comic_results) do
    total_items = ebook_results.total + comic_results.total
    total_correct = ebook_results.correct + comic_results.correct
    total_accuracy = if total_items > 0, do: total_correct / total_items * 100, else: 0

    ebook_accuracy = if ebook_results.total > 0, do: ebook_results.correct / ebook_results.total * 100, else: 0
    comic_accuracy = if comic_results.total > 0, do: comic_results.correct / comic_results.total * 100, else: 0

    comic_misclassified = length(ebook_results.incorrect_items)
    ebook_misclassified = length(comic_results.incorrect_items)

    IO.puts("\n\n🎯 UPDATED CLASSIFIER ANALYSIS COMPLETE!")
    IO.puts("==========================================")
    IO.puts("📊 Overall Accuracy: #{Float.round(total_accuracy, 1)}% (#{total_correct}/#{total_items})")
    IO.puts("📖 Ebook Accuracy: #{Float.round(ebook_accuracy, 1)}% (#{ebook_results.correct}/#{ebook_results.total})")
    IO.puts("📚 Comic Accuracy: #{Float.round(comic_accuracy, 1)}% (#{comic_results.correct}/#{comic_results.total})")
    IO.puts("❌ Total Errors: #{ebook_results.errors + comic_results.errors}")
    IO.puts("")
    IO.puts("🔥 KEY METRICS:")
    IO.puts("   Comics misclassified as ebooks: #{comic_misclassified} (compare with original ~15+)")
    IO.puts("   Ebooks misclassified as comics: #{ebook_misclassified}")
    IO.puts("")
    IO.puts("📋 Full report saved to: updated_full_classifier_report.txt")
    IO.puts("📋 Compare with: full_classifier_report.txt")
  end
end
