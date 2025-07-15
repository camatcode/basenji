defmodule Basenji.ComicClassifier do
  @moduledoc """
  Classifies comics vs ebooks using visual analysis and OCR validation.

  ## Classification Strategy
  1. Sample 4-6 representative pages (avoiding covers, starting from page 5)
  2. Visual analysis: saturation (40%), histogram bimodal (50%), edge density (10%)
  3. If overall visual score is uncertain (≥ 0.6) or invalid → OCR sample pages
  4. The OCR word-count average overrides visual analysis when triggered

  ## Usage
      {:ok, :ebook} = Classifier.classify(comic)
      {:ok, :comic, details} = Classifier.classify_with_details(comic)
  """

  alias Basenji.Comic
  alias Basenji.Comics
  alias Vix.Vips.Operation

  require Logger

  # Configuration
  @visual_threshold 0.6
  @classification_threshold 0.65
  @word_count_threshold 200
  @saturation_weight 0.4
  @bimodal_weight 0.5
  @edge_weight 0.1
  @max_concurrency 3

  @type classification :: :comic | :ebook
  @type details :: %{
          method: :visual | :ocr,
          confidence: float(),
          overall_visual_score: float() | nil,
          avg_word_count: float() | nil,
          pages_analyzed: integer(),
          processing_time_ms: integer(),
          page_details: [page_analysis()]
        }
  @type page_analysis :: %{
          page: integer(),
          visual_score: float() | nil,
          word_count: integer() | nil,
          ocr_confidence: float() | nil,
          processing_time_ms: integer()
        }

  @doc """
  Classifies a comic as either :comic or :ebook.
  """
  @spec classify(Comic.t()) :: {:ok, classification()} | {:error, term()}
  def classify(%Comic{} = comic) do
    case classify_with_details(comic) do
      {:ok, classification, _details} -> {:ok, classification}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Classifies a comic with detailed analysis breakdown.
  """
  @spec classify_with_details(Comic.t()) ::
          {:ok, classification(), details()} | {:error, term()}
  def classify_with_details(%Comic{} = comic) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, sample_pages} <- get_sample_pages(comic) do
      # Step 1: Analyze all pages visually first
      page_analyses = analyze_pages_visually(comic, sample_pages)

      # Step 2: Calculate overall visual score
      overall_visual_score = calculate_overall_visual_score(page_analyses)

      # Step 3: Decide if we need OCR based on overall score
      {final_page_analyses, method} =
        if should_apply_ocr?(overall_visual_score) do
          Logger.debug("Overall visual score uncertain (#{inspect(overall_visual_score)}), applying OCR to all pages")
          ocr_analyses = analyze_pages_with_ocr(comic, sample_pages)
          {ocr_analyses, :ocr}
        else
          Logger.debug("Overall visual score clear (#{overall_visual_score}), using visual analysis")
          {page_analyses, :visual}
        end

      # Step 4: Apply final classification
      end_time = System.monotonic_time(:millisecond)
      apply_classification_rules(final_page_analyses, overall_visual_score, method, end_time - start_time)
    end
  end

  # === PAGE SAMPLING ===

  defp get_sample_pages(%Comic{page_count: page_count}) when page_count < 5 do
    {:error, :insufficient_pages}
  end

  defp get_sample_pages(%Comic{page_count: page_count}) do
    sample_indices =
      case page_count do
        # 4 pages for shorter comics
        n when n <= 15 -> [5, div(n, 3) + 1, div(n * 2, 3), n - 2]
        # 5 pages for medium comics
        n when n <= 50 -> [20, div(n, 4) + 2, div(n, 2), div(n * 3, 4), n - 2]
        # 6 pages for longer comics
        n -> [350, div(n, 5) + 2, div(n * 2, 5), div(n * 3, 5), div(n * 4, 5), n - 2]
      end
      |> Enum.filter(&(&1 >= 3 and &1 <= page_count))
      |> Enum.uniq()

    {:ok, sample_indices}
  end

  # === VISUAL ANALYSIS (FIRST PASS) ===

  defp analyze_pages_visually(comic, page_indices) do
    page_indices
    |> Task.async_stream(&analyze_single_page_visually(comic, &1),
      max_concurrency: @max_concurrency,
      timeout: 10_000
    )
    |> Enum.map(fn
      {:ok, analysis} -> analysis
      {:exit, _reason} -> failed_page_analysis()
    end)
  end

  defp analyze_single_page_visually(comic, page_num) do
    start_time = System.monotonic_time(:millisecond)

    case Comics.get_page(comic, page_num) do
      {:ok, page_data, _content_type} ->
        temp_path = create_temp_file(page_data)

        try do
          visual_score = attempt_visual_analysis(temp_path)
          end_time = System.monotonic_time(:millisecond)

          %{
            page: page_num,
            visual_score: visual_score,
            word_count: nil,
            processing_time_ms: end_time - start_time
          }
        after
          File.rm(temp_path)
        end

      {:error, _} ->
        failed_page_analysis(page_num, start_time)
    end
  end

  defp attempt_visual_analysis(image_path) do
    case Image.open(image_path) do
      {:ok, image} ->
        # Visual analysis components
        saturation_score = analyze_saturation(image)
        bimodal_score = analyze_histogram_bimodal(image)
        edge_score = analyze_edge_density(image)
        comic_features = detect_comic_features(image)

        # Calculate visual score
        base_score =
          saturation_score * @saturation_weight +
            bimodal_score * @bimodal_weight +
            edge_score * @edge_weight

        base_score * (1.0 - comic_features * 0.3)

      # Visual analysis failed
      _ ->
        nil
    end
  end

  # === OVERALL VISUAL SCORE CALCULATION ===

  defp calculate_overall_visual_score(page_analyses) do
    scores = Enum.map(page_analyses, & &1.visual_score)
    non_nil_scores = Enum.filter(scores, &(&1 != nil))

    cond do
      # No valid scores at all
      Enum.empty?(non_nil_scores) -> nil
      # All valid scores are 0.0 (suspicious - likely analysis failure)
      Enum.all?(non_nil_scores, &(&1 == 0.0)) -> nil
      # Normal case - calculate average
      true -> Enum.sum(non_nil_scores) / length(non_nil_scores)
    end
  end

  # === OCR DECISION POINT ===

  defp should_apply_ocr?(overall_visual_score) do
    # OCR when uncertain (≥ 0.6) or when visual analysis failed (nil)
    overall_visual_score == nil or overall_visual_score >= @visual_threshold
  end

  # === OCR ANALYSIS (SECOND PASS) ===

  defp analyze_pages_with_ocr(comic, page_indices) do
    page_indices
    |> Task.async_stream(&analyze_single_page_with_ocr(comic, &1),
      max_concurrency: @max_concurrency,
      timeout: 30_000
    )
    |> Enum.map(fn
      {:ok, analysis} -> analysis
      {:exit, _reason} -> failed_page_analysis()
    end)
  end

  defp analyze_single_page_with_ocr(comic, page_num) do
    start_time = System.monotonic_time(:millisecond)

    case Comics.get_page(comic, page_num) do
      {:ok, page_data, _content_type} ->
        temp_path = create_temp_file(page_data)

        try do
          # Get visual score (might be nil if visual analysis failed)
          visual_score = attempt_visual_analysis(temp_path)

          # Always do OCR when in this path
          case perform_ocr_analysis(temp_path) do
            {:ok, word_count, avg_confidence} ->
              end_time = System.monotonic_time(:millisecond)

              %{
                page: page_num,
                visual_score: visual_score,
                word_count: word_count,
                ocr_confidence: avg_confidence,
                processing_time_ms: end_time - start_time
              }

            {:error, reason} ->
              raise(reason)
          end
        after
          File.rm(temp_path)
        end

      {:error, _} ->
        failed_page_analysis(page_num, start_time)
    end
  end

  defp failed_page_analysis(page_num \\ nil, start_time \\ nil) do
    end_time = System.monotonic_time(:millisecond)
    processing_time = if start_time, do: end_time - start_time, else: 0

    %{
      page: page_num,
      visual_score: nil,
      word_count: nil,
      processing_time_ms: processing_time
    }
  end

  # === VISUAL ANALYSIS COMPONENTS ===

  defp analyze_saturation(image) do
    {:ok, hsv} = Image.to_colorspace(image, :hsv)
    channels = Image.split_bands(hsv)
    sat_channel = Enum.at(channels, 1)
    [avg_sat] = Image.average(sat_channel)
    1.0 - avg_sat / 255.0
  rescue
    _ -> 0.0
  end

  defp analyze_histogram_bimodal(image) do
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
      analyze_text_like_distribution(histogram_values, total_pixels)
    else
      0.0
    end
  rescue
    _ -> 0.0
  end

  defp analyze_text_like_distribution(histogram_values, total_pixels) do
    # Light concentration (240-255 range)
    light_end = Enum.slice(histogram_values, 240, 16)
    max_light_peak = Enum.max(light_end)
    light_concentration = max_light_peak / total_pixels

    # Peak sharpness
    light_sorted = Enum.sort(light_end, :desc)

    peak_sharpness =
      if Enum.at(light_sorted, 1) > 0 do
        Enum.at(light_sorted, 0) / Enum.at(light_sorted, 1)
      else
        1.0
      end

    # Dark region characteristics (0-9 range)
    dark_end = Enum.slice(histogram_values, 0, 10)
    zeros_count = Enum.count(dark_end, &(&1 == 0))
    min_nonzero = dark_end |> Enum.filter(&(&1 > 0)) |> Enum.min(fn -> 0 end)

    # Bimodal distribution analysis
    dark_region = Enum.slice(histogram_values, 0, 80) |> Enum.sum()
    light_region = Enum.slice(histogram_values, 180, 76) |> Enum.sum()
    middle_region = Enum.slice(histogram_values, 80, 100) |> Enum.sum()

    dark_ratio = dark_region / total_pixels
    light_ratio = light_region / total_pixels
    middle_ratio = middle_region / total_pixels
    bimodal_strength = dark_ratio + light_ratio

    # Text detection criteria (require 5/6)
    criteria = [
      light_concentration > 0.20,
      peak_sharpness > 5.0,
      zeros_count <= 2,
      min_nonzero > 50,
      bimodal_strength > 0.60,
      middle_ratio < 0.35
    ]

    criteria_met = Enum.count(criteria, & &1)

    if criteria_met >= 5 do
      base_score = criteria_met / 6.0
      bimodal_bonus = bimodal_strength * 0.5
      (base_score + bimodal_bonus) |> min(1.0)
    else
      0.0
    end
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

  defp detect_comic_features(image) do
    {width, height, _bands} = Image.shape(image)
    aspect_ratio = width / height

    # Comic aspect ratio indicators
    cond do
      aspect_ratio > 0.6 and aspect_ratio < 0.8 -> 0.3
      aspect_ratio > 1.2 -> 0.5
      true -> 0.0
    end
  rescue
    _ -> 0.0
  end

  # === SHARED OCR METHOD ===

  defp perform_ocr_analysis(image_path) do
    args = [
      image_path,
      "stdout",
      "--oem",
      "1",
      "-c",
      "debug_file=/dev/null",
      "-c",
      "tessedit_create_tsv=1"
    ]

    case Porcelain.exec("tesseract", args, out: :string, err: :string) do
      %{status: 0, out: output, err: _stderr} ->
        parse_tsv_output(output)

      %{status: _error, err: error_msg} ->
        {:error, error_msg}
    end
  end

  defp parse_tsv_output(tsv_text) do
    lines = String.split(tsv_text, "\n", trim: true)

    # Skip header line, parse data lines
    word_data =
      lines
      # Skip TSV header
      |> Enum.drop(1)
      |> Enum.map(&parse_tsv_line/1)
      |> Enum.filter(&(&1 != nil))

    # Filter high-confidence meaningful words
    valid_words =
      Enum.filter(word_data, fn %{word: word, confidence: conf} ->
        String.length(word) >= 2 and
          String.match?(word, ~r/^[a-zA-Z][a-zA-Z0-9]*$/) and
          conf >= 60
      end)

    avg_confidence =
      if Enum.empty?(valid_words) do
        0.0
      else
        Enum.sum(Enum.map(valid_words, & &1.confidence)) / length(valid_words)
      end

    {:ok, length(valid_words), avg_confidence}
  end

  defp parse_tsv_line(line) do
    # TSV format: level, page_num, block_num, par_num, line_num, word_num, left, top, width, height, conf, text
    case String.split(line, "\t") do
      [_level, _page, _block, _par, _line, _word, _left, _top, _width, _height, conf_str, text] ->
        case Integer.parse(conf_str) do
          {confidence, _} when confidence >= 0 ->
            %{word: String.trim(text), confidence: confidence}

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  # === CLASSIFICATION LOGIC ===

  defp apply_classification_rules(page_analyses, overall_visual_score, method, processing_time) do
    case method do
      :visual ->
        # Use visual analysis only
        classification =
          if overall_visual_score > @classification_threshold do
            Logger.debug("EBOOK - visual score #{overall_visual_score} > #{@classification_threshold}")
            :ebook
          else
            Logger.debug("COMIC - visual score #{overall_visual_score} <= #{@classification_threshold}")
            :comic
          end

        confidence = calculate_visual_confidence(classification, overall_visual_score)

        details = %{
          method: :visual,
          confidence: confidence,
          overall_visual_score: overall_visual_score,
          avg_word_count: nil,
          pages_analyzed: length(page_analyses),
          processing_time_ms: processing_time,
          page_details: page_analyses
        }

        {:ok, classification, details}

      :ocr ->
        # Use OCR analysis (overrides visual)
        word_counts =
          page_analyses
          |> Enum.filter(&(&1.ocr_confidence && &1.ocr_confidence > 50))
          |> Enum.map(& &1.word_count)
          |> Enum.filter(&(&1 != nil))

        if Enum.empty?(word_counts) do
          # OCR failed on all pages, fall back to visual if available
          if overall_visual_score do
            apply_classification_rules(page_analyses, overall_visual_score, :visual, processing_time)
          else
            {:error, :no_valid_analysis}
          end
        else
          avg_word_count = Enum.sum(word_counts) / length(word_counts)

          Logger.debug("OCR analysis: #{length(word_counts)} pages, average #{avg_word_count} words")

          classification =
            if avg_word_count >= @word_count_threshold do
              Logger.debug("EBOOK - average word count #{avg_word_count} >= #{@word_count_threshold}")
              :ebook
            else
              Logger.debug("COMIC - average word count #{avg_word_count} < #{@word_count_threshold}")
              :comic
            end

          confidence = calculate_ocr_confidence(classification, avg_word_count)

          details = %{
            method: :ocr,
            confidence: confidence,
            overall_visual_score: overall_visual_score,
            avg_word_count: avg_word_count,
            pages_analyzed: length(page_analyses),
            processing_time_ms: processing_time,
            page_details: page_analyses
          }

          {:ok, classification, details}
        end
    end
  end

  defp calculate_visual_confidence(classification, visual_score) do
    case classification do
      :ebook ->
        # Confidence based on how far above threshold
        distance = visual_score - @classification_threshold
        min(0.5 + distance * 2, 1.0)

      :comic ->
        # Confidence based on how far below threshold
        distance = @classification_threshold - visual_score
        min(0.5 + distance * 2, 1.0)
    end
  end

  defp calculate_ocr_confidence(classification, avg_word_count) do
    case classification do
      :ebook ->
        # High confidence when well above threshold
        distance = avg_word_count - @word_count_threshold
        min(0.7 + distance / 1000, 1.0)

      :comic ->
        # High confidence when well below threshold
        distance = @word_count_threshold - avg_word_count
        min(0.7 + distance / @word_count_threshold, 1.0)
    end
  end

  # === UTILITIES ===

  defp create_temp_file(page_data) do
    temp_path = Path.join([System.tmp_dir(), "basenji", "classifier_#{:rand.uniform(999_999)}.jpg"])
    File.write!(temp_path, page_data)
    temp_path
  end
end
