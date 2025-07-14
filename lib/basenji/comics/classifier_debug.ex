defmodule Basenji.Comics.ClassifierDebug do
  @moduledoc """
  Debug version of the classifier that shows detailed scoring breakdown.
  """

  alias Basenji.Comics
  alias Vix.Vips.Operation

  require Logger

  def debug_classify_comic(comic_id) do
    with {:ok, comic} <- Comics.get_comic(comic_id) do
      IO.puts("\n🔍 DEBUG: #{comic.title || "Untitled"} (#{comic.id})")
      IO.puts("   Resource: #{comic.resource_location}")
      IO.puts("   Format: #{comic.format}, Pages: #{comic.page_count}")

      sample_pages = get_sample_pages(comic)
      IO.puts("   Sampling pages: #{inspect(sample_pages)}")

      detailed_scores =
        sample_pages
        |> Enum.map(fn page_num ->
          debug_analyze_single_page(comic, page_num)
        end)

      # Calculate averages
      saturation_scores = Enum.map(detailed_scores, & &1.saturation)
      bimodal_scores = Enum.map(detailed_scores, & &1.bimodal)
      edge_scores = Enum.map(detailed_scores, & &1.edge)
      final_scores = Enum.map(detailed_scores, & &1.final)

      avg_saturation = Enum.sum(saturation_scores) / length(saturation_scores)
      avg_bimodal = Enum.sum(bimodal_scores) / length(bimodal_scores)
      avg_edge = Enum.sum(edge_scores) / length(edge_scores)
      avg_final = Enum.sum(final_scores) / length(final_scores)

      IO.puts("\n   📊 Individual Page Scores:")

      Enum.zip(sample_pages, detailed_scores)
      |> Enum.each(fn {page, scores} ->
        IO.puts(
          "      Page #{page}: sat=#{Float.round(scores.saturation, 3)}, bimodal=#{Float.round(scores.bimodal, 3)}, edge=#{Float.round(scores.edge, 3)} → #{Float.round(scores.final, 3)}"
        )
      end)

      IO.puts("\n   📈 Average Scores:")
      IO.puts("      Saturation: #{Float.round(avg_saturation, 3)} (low sat = ebook)")
      IO.puts("      Bimodal:    #{Float.round(avg_bimodal, 3)} (high bimodal = ebook)")
      IO.puts("      Edge:       #{Float.round(avg_edge, 3)} (high edge = ebook)")
      IO.puts("      Final:      #{Float.round(avg_final, 3)} (threshold: 0.6)")

      classification = if avg_final > 0.6, do: :ebook, else: :comic
      IO.puts("   🎯 Result: #{classification}")

      classification
    end
  end

  defp debug_analyze_single_page(comic, page_num) do
    case Comics.get_page(comic, page_num) do
      {:ok, page_data, _content_type} ->
        temp_path = create_temp_file(page_data)

        try do
          {:ok, image} = Image.open(temp_path)

          saturation_score = analyze_saturation(image)
          bimodal_score = analyze_histogram_bimodal(image)
          edge_score = analyze_edge_density(image)

          # Same weighted combination as main classifier - updated weights
          final_score = saturation_score * 0.4 + bimodal_score * 0.5 + edge_score * 0.1

          %{
            saturation: saturation_score,
            bimodal: bimodal_score,
            edge: edge_score,
            final: final_score
          }
        rescue
          e ->
            IO.puts("      ❌ Error analyzing page #{page_num}: #{inspect(e)}")
            %{saturation: 0.0, bimodal: 0.0, edge: 0.0, final: 0.0}
        after
          File.rm(temp_path)
        end

      {:error, reason} ->
        IO.puts("      ❌ Failed to get page #{page_num}: #{inspect(reason)}")
        %{saturation: 0.0, bimodal: 0.0, edge: 0.0, final: 0.0}
    end
  end

  defp get_sample_pages(comic) do
    page_count = comic.page_count || 0

    case page_count do
      n when n < 3 -> []
      # Just pages 2-3 for very short comics
      n when n <= 5 -> [2, 3]
      # Beginning, middle, near-end
      n when n <= 10 -> [2, div(n, 2), n - 1]
      # Three content pages from different sections
      n -> [2, div(n, 3), div(n * 2, 3)]
    end
  end

  defp create_temp_file(page_data) do
    temp_path = Path.join([System.tmp_dir(), "basenji_debug_#{:rand.uniform(999_999)}.jpg"])
    File.write!(temp_path, page_data)
    temp_path
  end

  # Fixed analysis functions using correct Image library API
  defp analyze_saturation(image) do
    {:ok, hsv} = Image.to_colorspace(image, :hsv)
    # Image.split_bands returns list directly
    channels = Image.split_bands(hsv)
    sat_channel = Enum.at(channels, 1)

    # Image.average returns list directly
    [avg_sat] = Image.average(sat_channel)

    1.0 - avg_sat / 255.0
  rescue
    _ -> 0.0
  end

  # NEW: Use the same sophisticated histogram analysis as main classifier
  defp analyze_histogram_bimodal(image) do
    {:ok, gray} = Image.to_colorspace(image, :bw)
    # Use Vix.Vips.Operation.hist_find for actual pixel counts
    {:ok, histogram_image} = Operation.hist_find(gray)

    # Extract histogram values using getpoint - histogram is 256x1 grayscale image
    histogram_values =
      for x <- 0..255 do
        case Operation.getpoint(histogram_image, x, 0) do
          {:ok, [value]} -> round(value)
          _ -> 0
        end
      end

    total_pixels = Enum.sum(histogram_values)

    if total_pixels > 0 do
      # Advanced text detection using histogram shape characteristics
      analyze_text_like_distribution(histogram_values, total_pixels)
    else
      0.0
    end
  rescue
    _ -> 0.0
  end

  # Analyze histogram shape to distinguish text from comic art
  defp analyze_text_like_distribution(histogram_values, total_pixels) do
    # 1. PEAK CONCENTRATION - Text has sharp peaks at light end
    # 240-255 (very bright)
    light_end = Enum.slice(histogram_values, 240, 16)
    max_light_peak = Enum.max(light_end)
    light_concentration = max_light_peak / total_pixels

    # 2. PEAK SHARPNESS - Text has dominant single peaks
    light_sorted = Enum.sort(light_end, :desc)

    peak_sharpness =
      if Enum.at(light_sorted, 1) > 0 do
        Enum.at(light_sorted, 0) / Enum.at(light_sorted, 1)
      else
        1.0
      end

    # 3. DARK REGION CHARACTERISTICS - Text avoids pure black
    # 0-9 (very dark)
    dark_end = Enum.slice(histogram_values, 0, 10)
    zeros_count = Enum.count(dark_end, &(&1 == 0))
    min_nonzero = dark_end |> Enum.filter(&(&1 > 0)) |> Enum.min(fn -> 0 end)

    # 4. BIMODAL STRENGTH with broader ranges for anti-aliasing
    # 0-79
    dark_region = Enum.slice(histogram_values, 0, 80) |> Enum.sum()
    # 180-255
    light_region = Enum.slice(histogram_values, 180, 76) |> Enum.sum()
    # 80-179
    middle_region = Enum.slice(histogram_values, 80, 100) |> Enum.sum()

    dark_ratio = dark_region / total_pixels
    light_ratio = light_region / total_pixels
    middle_ratio = middle_region / total_pixels
    bimodal_strength = dark_ratio + light_ratio

    # TEXT-LIKE CRITERIA (same as main classifier):
    text_criteria = [
      # Sharp light peaks
      light_concentration > 0.20,
      # Dominant peaks
      peak_sharpness > 5.0,
      # Few pure blacks
      zeros_count <= 2,
      # Anti-aliasing evidence
      min_nonzero > 50,
      # Strong bimodal
      bimodal_strength > 0.60,
      # Limited middle tones
      middle_ratio < 0.35
    ]

    criteria_met = Enum.count(text_criteria, & &1)

    # Need to meet at least 5 out of 6 criteria for text-like classification
    if criteria_met >= 5 do
      # Score based on how many criteria are met and strength of bimodal distribution
      # 0.83 to 1.0
      base_score = criteria_met / 6.0
      bimodal_bonus = bimodal_strength * 0.5

      (base_score + bimodal_bonus) |> min(1.0)
    else
      0.0
    end
  end

  defp analyze_edge_density(image) do
    {:ok, sharpened} = Image.sharpen(image)

    # Image.average returns list directly
    original_bands = Image.average(image)
    original_avg = Enum.sum(original_bands) / length(original_bands)

    sharpened_bands = Image.average(sharpened)
    sharpened_avg = Enum.sum(sharpened_bands) / length(sharpened_bands)

    edge_response = abs(sharpened_avg - original_avg) / 255.0
    min(edge_response * 3.0, 1.0)
  rescue
    _ -> 0.0
  end
end
