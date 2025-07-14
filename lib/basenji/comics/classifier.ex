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
      classification = if avg_score > 0.7, do: :ebook, else: :comic

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

    if page_count < 5 do
      {:error, :no_pages}
    else
      # Sample more pages, avoiding covers and preferring later content pages
      # Skip first 2 pages (covers/title) and last page (back cover/blank)
      # Sample from content pages throughout the book
      sample_indices =
        case page_count do
          # Sample 4 pages for shorter comics
          n when n <= 15 -> [3, div(n, 3) + 1, div(n * 2, 3), n - 2]
          # Sample 5 pages for medium comics  
          n when n <= 50 -> [3, div(n, 4) + 2, div(n, 2), div(n * 3, 4), n - 2]
          # Sample 6 pages for longer comics
          n -> [3, div(n, 5) + 2, div(n * 2, 5), div(n * 3, 5), div(n * 4, 5), n - 2]
        end
        # Ensure valid page numbers
        |> Enum.filter(&(&1 >= 3 and &1 <= page_count))
        # Remove duplicates
        |> Enum.uniq()

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
      comic_features = detect_comic_features(image)

      # Weighted combination - tune these weights based on testing
      # Saturation is very reliable for ebooks, histogram is good, edge detection needs work
      base_score = saturation_score * 0.4 + bimodal_score * 0.5 + edge_score * 0.1

      # Apply comic feature penalty - reduce score if comic features detected
      final_score = base_score * (1.0 - comic_features * 0.3)

      {:ok, final_score}
    end
  end

  # Detect comic-specific features to help distinguish from text
  defp detect_comic_features(image) do
    panel_borders = detect_panel_borders(image)
    aspect_ratio = analyze_aspect_ratio(image)

    # Combine features into a confidence score (0.0 = no comic features, 1.0 = strong comic features)
    panel_borders * 0.7 + aspect_ratio * 0.3
  end

  # Detect panel borders by looking for strong horizontal/vertical lines
  defp detect_panel_borders(image) do
    {:ok, gray} = Image.to_colorspace(image, :bw)

    # Use Sobel edge detection to find strong edges
    {:ok, edges} = Operation.sobel(gray)

    # Get image dimensions
    {width, height, _bands} = Image.shape(edges)

    # Sample edge strength at regular intervals
    # Check for strong horizontal and vertical lines (panel borders)
    horizontal_strength = check_horizontal_lines(edges, width, height)
    vertical_strength = check_vertical_lines(edges, width, height)

    # Panel borders tend to have both horizontal and vertical structure
    max(horizontal_strength, vertical_strength)
  rescue
    _ -> 0.0
  end

  # Check for horizontal line patterns (panel borders)
  defp check_horizontal_lines(edges, width, height) do
    # Sample a few horizontal lines across the image
    sample_rows = [div(height, 4), div(height, 2), div(height * 3, 4)]

    row_strengths =
      for row <- sample_rows do
        # Sample points across this row
        sample_points = for x <- 0..min(width - 1, 10)//1, do: x * div(width, 11)

        # Get edge values at these points
        edge_values =
          for x <- sample_points do
            case Operation.getpoint(edges, x, row) do
              {:ok, [value]} -> value
              _ -> 0.0
            end
          end

        # Strong horizontal lines should have consistent high values
        avg_strength = Enum.sum(edge_values) / length(edge_values)
        avg_strength / 255.0
      end

    Enum.max(row_strengths)
  rescue
    _ -> 0.0
  end

  # Check for vertical line patterns (panel borders)
  defp check_vertical_lines(edges, width, height) do
    # Sample a few vertical lines across the image
    sample_cols = [div(width, 4), div(width, 2), div(width * 3, 4)]

    col_strengths =
      for col <- sample_cols do
        # Sample points down this column
        sample_points = for y <- 0..min(height - 1, 10)//1, do: y * div(height, 11)

        # Get edge values at these points
        edge_values =
          for y <- sample_points do
            case Operation.getpoint(edges, col, y) do
              {:ok, [value]} -> value
              _ -> 0.0
            end
          end

        # Strong vertical lines should have consistent high values
        avg_strength = Enum.sum(edge_values) / length(edge_values)
        avg_strength / 255.0
      end

    Enum.max(col_strengths)
  rescue
    _ -> 0.0
  end

  # Analyze aspect ratio - comics tend to have certain ratios
  defp analyze_aspect_ratio(image) do
    {width, height, _bands} = Image.shape(image)

    aspect_ratio = width / height

    # Comic pages often have ratios around 0.65-0.75 (taller than wide)
    # Ebook pages tend to be closer to 0.7-0.8 but can vary widely
    # This is a weak signal but can help in borderline cases
    cond do
      # Mild comic indicator
      aspect_ratio > 0.6 and aspect_ratio < 0.8 -> 0.3
      # Wide format often indicates comic spreads
      aspect_ratio > 1.2 -> 0.5
      # Neutral
      true -> 0.0
    end
  rescue
    _ -> 0.0
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

    # Need to meet all 6 criteria for text-like classification (stricter)
    if criteria_met >= 6 do
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
