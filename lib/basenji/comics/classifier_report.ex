defmodule Basenji.Comics.ClassifierReport do
  @moduledoc """
  Comprehensive testing and reporting tool for the comic/ebook classifier.

  Analyzes all comics and ebooks in the database, writes detailed reports,
  and provides insights into classification patterns and accuracy.
  """

  alias Basenji.Comics
  alias Vix.Vips.Operation

  require Logger

  @doc """
  Run comprehensive analysis on all comics and ebooks.
  Writes detailed report to file and returns summary statistics.

  Options:
  - `:output_file` - Path to write report (default: "classifier_report.txt")
  - `:limit` - Maximum number of items to test (default: nil for all)
  - `:include_criteria_details` - Include detailed criteria breakdown (default: true)
  """
  def run_full_analysis(opts \\ []) do
    output_file = Keyword.get(opts, :output_file, "classifier_report.txt")
    limit = Keyword.get(opts, :limit)
    include_details = Keyword.get(opts, :include_criteria_details, true)

    IO.puts("🔍 Starting comprehensive classifier analysis...")
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
      ebook_results = analyze_items(ebooks, :ebook, file, include_details)

      # Analyze comics  
      IO.puts("🔍 Analyzing comics...")
      comic_results = analyze_items(comics, :comic, file, include_details)

      # Write summary
      write_summary(file, ebook_results, comic_results)

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

  # Analyze a list of items (ebooks or comics)
  defp analyze_items(items, expected_type, file, include_details) do
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
      analyze_single_item(item, expected_type, file, include_details, acc)
    end)
  end

  defp analyze_single_item(item, expected_type, file, include_details, acc) do
    # Progress indicator
    IO.write(".")

    start_time = System.monotonic_time(:millisecond)

    case Comics.Classifier.classify_comic(item.id) do
      {:ok, actual_type} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        correct = actual_type == expected_type

        # Get detailed scores if requested
        detailed_scores =
          if include_details do
            get_detailed_analysis(item.id)
          end

        # Write to report
        write_item_result(file, item, expected_type, actual_type, correct, duration, detailed_scores)

        # Update accumulator
        if correct do
          %{acc | correct: acc.correct + 1, correct_items: [item | acc.correct_items]}
        else
          %{
            acc
            | incorrect: acc.incorrect + 1,
              incorrect_items: [{item, actual_type, detailed_scores} | acc.incorrect_items]
          }
        end

      {:error, reason} ->
        write_error_result(file, item, expected_type, reason)
        %{acc | errors: acc.errors + 1, error_items: [{item, reason} | acc.error_items]}
    end
  end

  defp get_detailed_analysis(comic_id) do
    # Get the detailed breakdown without debug output
    case Comics.get_comic(comic_id) do
      {:ok, comic} ->
        sample_pages = get_sample_pages(comic)

        page_details =
          Enum.map(sample_pages, fn page_num ->
            case Comics.get_page(comic, page_num) do
              {:ok, page_data, _} ->
                temp_path = Path.join([System.tmp_dir(), "report_analyze_#{:rand.uniform(999_999)}.jpg"])
                File.write!(temp_path, page_data)

                try do
                  {:ok, image} = Image.open(temp_path)

                  sat_score = analyze_saturation(image)
                  {bimodal_score, criteria_breakdown} = analyze_histogram_with_details(image)
                  edge_score = analyze_edge_density(image)
                  final_score = sat_score * 0.4 + bimodal_score * 0.5 + edge_score * 0.1

                  %{
                    page: page_num,
                    saturation: sat_score,
                    bimodal: bimodal_score,
                    edge: edge_score,
                    final: final_score,
                    criteria: criteria_breakdown
                  }
                rescue
                  _ -> %{page: page_num, error: "Analysis failed"}
                after
                  File.rm(temp_path)
                end

              _ ->
                %{page: page_num, error: "Page extraction failed"}
            end
          end)

        %{
          sample_pages: sample_pages,
          page_details: page_details,
          avg_saturation: avg_score(page_details, :saturation),
          avg_bimodal: avg_score(page_details, :bimodal),
          avg_edge: avg_score(page_details, :edge),
          avg_final: avg_score(page_details, :final)
        }

      _ ->
        nil
    end
  end

  # Helper functions for detailed analysis (copied from classifier)
  defp get_sample_pages(comic) do
    page_count = comic.page_count || 0

    case page_count do
      n when n < 3 -> []
      n when n <= 5 -> [2, 3]
      n when n <= 10 -> [2, div(n, 2), n - 1]
      n -> [2, div(n, 3), div(n * 2, 3)]
    end
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

  defp analyze_histogram_with_details(image) do
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
      # Calculate all criteria with details
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

      criteria = [
        {:light_concentration, light_concentration > 0.20, light_concentration},
        {:peak_sharpness, peak_sharpness > 5.0, peak_sharpness},
        {:zeros_count, zeros_count <= 2, zeros_count},
        {:min_nonzero, min_nonzero > 50, min_nonzero},
        {:bimodal_strength, bimodal_strength > 0.60, bimodal_strength},
        {:middle_ratio, middle_ratio < 0.35, middle_ratio}
      ]

      criteria_met = Enum.count(criteria, fn {_, passed, _} -> passed end)

      score =
        if criteria_met >= 5 do
          base_score = criteria_met / 6.0
          bimodal_bonus = bimodal_strength * 0.5
          (base_score + bimodal_bonus) |> min(1.0)
        else
          0.0
        end

      {score, %{criteria: criteria, criteria_met: criteria_met}}
    else
      {0.0, %{criteria: [], criteria_met: 0}}
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

  defp avg_score(page_details, key) do
    scores =
      page_details
      |> Enum.map(&Map.get(&1, key))
      |> Enum.filter(&is_number/1)

    if Enum.empty?(scores) do
      0.0
    else
      Enum.sum(scores) / length(scores)
    end
  end

  # Report writing functions
  defp write_report_header(file, ebooks, comics) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()

    IO.write(file, """
    ================================================================================
    COMIC/EBOOK CLASSIFIER ANALYSIS REPORT
    ================================================================================
    Generated: #{timestamp}

    DATASET OVERVIEW:
    - Total Items: #{length(ebooks) + length(comics)}
    - Ebooks: #{length(ebooks)}
    - Comics: #{length(comics)}

    CLASSIFIER CONFIGURATION:
    - Saturation Weight: 0.4
    - Bimodal Weight: 0.5  
    - Edge Weight: 0.1
    - Classification Threshold: 0.6
    - Criteria Required: 5/6 for text classification

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

  defp write_item_result(file, item, expected, actual, correct, duration, details) do
    status = if correct, do: "✅ CORRECT", else: "❌ INCORRECT"
    title = String.slice(item.title || "Untitled", 0, 60)
    filename = Path.basename(item.resource_location)

    IO.write(file, """
    #{status} | #{expected} → #{actual} | #{duration}ms
    Title: #{title}
    File: #{filename}
    Pages: #{item.page_count}
    """)

    if details do
      IO.write(file, """
      Scores: sat=#{Float.round(details.avg_saturation, 3)} bio=#{Float.round(details.avg_bimodal, 3)} edge=#{Float.round(details.avg_edge, 3)} → #{Float.round(details.avg_final, 3)}
      Sample Pages: #{inspect(details.sample_pages)}
      """)

      # Write detailed criteria for incorrect classifications
      if not correct and details.page_details do
        IO.write(file, "  Detailed Analysis:\n")

        Enum.each(details.page_details, fn page_detail ->
          if page_detail[:criteria] do
            criteria = page_detail.criteria
            IO.write(file, "    Page #{page_detail.page}: #{page_detail.criteria.criteria_met}/6 criteria met\n")

            Enum.each(criteria.criteria, fn {name, passed, value} ->
              status = if passed, do: "✅", else: "❌"
              formatted_value = if is_float(value), do: Float.round(value, 3), else: value
              IO.write(file, "      #{status} #{name}: #{formatted_value}\n")
            end)
          end
        end)
      end
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

  defp write_summary(file, ebook_results, comic_results) do
    total_items = ebook_results.total + comic_results.total
    total_correct = ebook_results.correct + comic_results.correct
    total_accuracy = if total_items > 0, do: total_correct / total_items * 100, else: 0

    ebook_accuracy = if ebook_results.total > 0, do: ebook_results.correct / ebook_results.total * 100, else: 0
    comic_accuracy = if comic_results.total > 0, do: comic_results.correct / comic_results.total * 100, else: 0

    IO.write(file, """

    ================================================================================
    SUMMARY STATISTICS
    ================================================================================

    OVERALL PERFORMANCE:
    - Total Accuracy: #{Float.round(total_accuracy, 1)}% (#{total_correct}/#{total_items})
    - Processing Errors: #{ebook_results.errors + comic_results.errors}

    EBOOK CLASSIFICATION:
    - Accuracy: #{Float.round(ebook_accuracy, 1)}% (#{ebook_results.correct}/#{ebook_results.total})
    - Misclassified as Comics: #{ebook_results.incorrect}
    - Errors: #{ebook_results.errors}

    COMIC CLASSIFICATION:  
    - Accuracy: #{Float.round(comic_accuracy, 1)}% (#{comic_results.correct}/#{comic_results.total})
    - Misclassified as Ebooks: #{comic_results.incorrect}
    - Errors: #{comic_results.errors}

    """)

    # Write failure analysis
    if not Enum.empty?(ebook_results.incorrect_items) do
      IO.write(file, "EBOOKS MISCLASSIFIED AS COMICS:\n")

      Enum.each(ebook_results.incorrect_items, fn {item, _actual_type, details} ->
        IO.write(file, "- #{item.title || "Untitled"}\n")

        if details do
          IO.write(file, "  Final Score: #{Float.round(details.avg_final, 3)} (below 0.6 threshold)\n")
          # Find most common failure reasons
          if details.page_details do
            criteria_failures = analyze_criteria_failures(details.page_details)
            IO.write(file, "  Common Failures: #{inspect(criteria_failures)}\n")
          end
        end
      end)

      IO.write(file, "\n")
    end

    if not Enum.empty?(comic_results.incorrect_items) do
      IO.write(file, "COMICS MISCLASSIFIED AS EBOOKS:\n")

      Enum.each(comic_results.incorrect_items, fn {item, _actual_type, details} ->
        IO.write(file, "- #{item.title || "Untitled"}\n")

        if details do
          IO.write(file, "  Final Score: #{Float.round(details.avg_final, 3)} (above 0.6 threshold)\n")
        end
      end)
    end

    IO.write(file, "\n================================================================================\n")
  end

  defp analyze_criteria_failures(page_details) do
    all_criteria =
      Enum.flat_map(page_details, fn page ->
        if page[:criteria] && page.criteria[:criteria] do
          page.criteria.criteria
        else
          []
        end
      end)

    failed_criteria = Enum.filter(all_criteria, fn {_, passed, _} -> not passed end)

    failed_criteria
    |> Enum.map(fn {name, _, _} -> name end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(3)
  end

  defp print_console_summary(ebook_results, comic_results) do
    total_items = ebook_results.total + comic_results.total
    total_correct = ebook_results.correct + comic_results.correct
    total_accuracy = if total_items > 0, do: total_correct / total_items * 100, else: 0

    ebook_accuracy = if ebook_results.total > 0, do: ebook_results.correct / ebook_results.total * 100, else: 0
    comic_accuracy = if comic_results.total > 0, do: comic_results.correct / comic_results.total * 100, else: 0

    IO.puts("\n\n🎯 ANALYSIS COMPLETE!")
    IO.puts("=====================")
    IO.puts("📊 Overall Accuracy: #{Float.round(total_accuracy, 1)}% (#{total_correct}/#{total_items})")
    IO.puts("📖 Ebook Accuracy: #{Float.round(ebook_accuracy, 1)}% (#{ebook_results.correct}/#{ebook_results.total})")
    IO.puts("📚 Comic Accuracy: #{Float.round(comic_accuracy, 1)}% (#{comic_results.correct}/#{comic_results.total})")
    IO.puts("❌ Total Errors: #{ebook_results.errors + comic_results.errors}")
  end

  defp calculate_total_accuracy(ebook_results, comic_results) do
    total_items = ebook_results.total + comic_results.total
    total_correct = ebook_results.correct + comic_results.correct
    if total_items > 0, do: total_correct / total_items * 100, else: 0
  end
end
