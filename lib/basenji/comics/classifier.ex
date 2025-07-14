defmodule Basenji.Comics.Classifier do
  @moduledoc """
  Classifies comics as either :comic or :ebook based on image analysis.

  Uses histogram analysis and other fast image metrics to determine if pages
  are primarily text-based (ebook) or image-based (comic).
  """

  alias Basenji.Comics
  alias Vix.Vips.Operation

  require Logger

  @doc """
  Classifies a single comic by analyzing sample pages.

  Returns `{:ok, :comic | :ebook}` or `{:error, reason}`
  """
  def classify_comic(comic_id) do
    with {:ok, comic} <- Comics.get_comic(comic_id),
         {:ok, sample_pages} <- get_sample_pages(comic),
         {:ok, scores} <- analyze_pages(comic, sample_pages) do
      avg_score = Enum.sum(scores) / length(scores)
      classification = if avg_score > 0.6, do: :ebook, else: :comic

      Logger.debug("Comic #{comic_id}: scores=#{inspect(scores)}, avg=#{avg_score}, result=#{classification}")

      {:ok, classification}
    end
  end

  @doc """
  Batch classify multiple comics and return results.
  Useful for testing on your dataset.
  """
  def batch_classify(comic_ids, opts \\ []) do
    max_concurrency = Keyword.get(opts, :max_concurrency, 5)

    comic_ids
    |> Task.async_stream(&classify_with_id/1,
      max_concurrency: max_concurrency,
      timeout: 30_000
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, reason}
    end)
  end

  @doc """
  Quick test function - classify first N comics and show results
  """
  def test_classification(limit \\ 10) do
    Comics.list_comics(limit: limit)
    |> Enum.map(& &1.id)
    |> batch_classify()
    |> Enum.each(fn
      {:ok, comic_id, classification} ->
        IO.puts("Comic #{comic_id}: #{classification}")

      {:error, comic_id, reason} ->
        IO.puts("Comic #{comic_id}: ERROR - #{inspect(reason)}")
    end)
  end

  # Private functions

  defp classify_with_id(comic_id) do
    case classify_comic(comic_id) do
      {:ok, classification} -> {:ok, comic_id, classification}
      {:error, reason} -> {:error, comic_id, reason}
    end
  end

  defp get_sample_pages(comic) do
    page_count = comic.page_count || 0

    if page_count < 3 do
      {:error, :no_pages}
    else
      # Sample content pages, avoiding covers
      # Skip first page (likely cover) and last page (likely back cover/blank)
      # Sample from the middle content pages
      sample_indices =
        case page_count do
          # Just pages 2-3 for very short comics
          n when n <= 5 -> [2, 3]
          # Beginning, middle, near-end
          n when n <= 10 -> [2, div(n, 2), n - 1]
          # Three content pages from different sections
          n -> [2, div(n, 3), div(n * 2, 3)]
        end

      {:ok, sample_indices}
    end
  end

  defp analyze_pages(comic, page_indices) do
    scores =
      page_indices
      |> Task.async_stream(
        fn page_num ->
          analyze_single_page(comic, page_num)
        end,
        max_concurrency: 3,
        timeout: 10_000
      )
      |> Enum.map(fn
        {:ok, score} -> score
        # Default score for failed pages
        {:exit, _reason} -> 0.0
      end)

    if Enum.all?(scores, &(&1 == 0.0)) do
      {:error, :no_valid_pages}
    else
      {:ok, scores}
    end
  end

  defp analyze_single_page(comic, page_num) do
    case Comics.get_page(comic, page_num) do
      {:ok, page_data, _content_type} ->
        # Write to temporary file for Image library
        temp_path = create_temp_file(page_data)

        try do
          {:ok, score} = analyze_page_image(temp_path)
          score
        rescue
          _ -> 0.0
        after
          File.rm(temp_path)
        end

      {:error, _} ->
        0.0
    end
  end

  defp create_temp_file(page_data) do
    temp_path = Path.join([System.tmp_dir(), "basenji_classify_#{:rand.uniform(999_999)}.jpg"])
    File.write!(temp_path, page_data)
    temp_path
  end

  defp analyze_page_image(image_path) do
    with {:ok, image} <- Image.open(image_path) do
      # Combine multiple metrics
      saturation_score = analyze_saturation(image)
      bimodal_score = analyze_histogram_bimodal(image)
      edge_score = analyze_edge_density(image)

      # Weighted combination - tune these weights based on testing
      # Saturation is very reliable for ebooks, histogram is good, edge detection needs work
      final_score = saturation_score * 0.4 + bimodal_score * 0.5 + edge_score * 0.1

      {:ok, final_score}
    end
  end

  # Convert to HSV and check saturation channel
  # Low saturation = more likely ebook
  defp analyze_saturation(image) do
    {:ok, hsv} = Image.to_colorspace(image, :hsv)
    # Image.split_bands returns list directly, no {:ok, ...}
    channels = Image.split_bands(hsv)
    # S channel is second (index 1)
    sat_channel = Enum.at(channels, 1)

    # Image.average returns list directly
    [avg_sat] = Image.average(sat_channel)

    # Return score where 1.0 = likely ebook, 0.0 = likely comic
    1.0 - avg_sat / 255.0
  rescue
    _ -> 0.0
  end

  # Convert to grayscale and analyze histogram for text-like distribution
  defp analyze_histogram_bimodal(image) do
    {:ok, gray} = Image.to_colorspace(image, :bw)
    # Use Vix.Vips.Operation.hist_find to get actual pixel counts
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

    # TEXT-LIKE CRITERIA (more restrictive than before):
    # 1. Sharp light peak concentration (>20% of pixels in brightest area)
    # 2. Dominant peak sharpness (>5x stronger than second peak)
    # 3. Limited pure blacks (≤2 zero values in dark end)
    # 4. Anti-aliasing evidence (minimum dark value >50)
    # 5. Strong bimodal distribution (>60% in dark+light regions)
    # 6. Limited middle region (<35%)

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
      # 0.67 to 1.0
      base_score = criteria_met / 6.0
      bimodal_bonus = bimodal_strength * 0.5

      (base_score + bimodal_bonus) |> min(1.0)
    else
      0.0
    end
  end

  # Text has high edge density due to character boundaries  
  # Use sharpen as a proxy for edge content (simplified version)
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
