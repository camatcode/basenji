defmodule Basenji.Comics.ClassifierVerboseDebug do
  @moduledoc """
  Super verbose debug version to see what's happening in image processing.
  """

  alias Basenji.Comics
  alias Vix.Vips.Operation

  def super_debug_single_page(comic_id, page_num \\ 1) do
    with {:ok, comic} <- Comics.get_comic(comic_id) do
      IO.puts("\n🔍 SUPER DEBUG: #{comic.title}")
      IO.puts("   Analyzing page #{page_num}")

      case Comics.get_page(comic, page_num) do
        {:ok, page_data, content_type} ->
          IO.puts("   ✅ Got page data: #{byte_size(page_data)} bytes, type: #{content_type}")

          temp_path = create_temp_file(page_data)
          IO.puts("   📁 Temp file: #{temp_path}")

          try do
            IO.puts("   🖼️  Opening image...")
            {:ok, image} = Image.open(temp_path)
            {width, height, bands} = Image.shape(image)
            IO.puts("   📐 Image size: #{width}x#{height}, #{bands} bands")

            # Test each function individually
            debug_saturation(image)
            debug_histogram(image)
            debug_edge_detection(image)
          rescue
            e ->
              IO.puts("   ❌ Error: #{inspect(e)}")
          after
            File.rm(temp_path)
          end

        {:error, reason} ->
          IO.puts("   ❌ Failed to get page: #{inspect(reason)}")
      end
    end
  end

  defp debug_saturation(image) do
    IO.puts("\n   🎨 SATURATION Analysis:")

    try do
      IO.puts("      Converting to HSV...")
      {:ok, hsv} = Image.to_colorspace(image, :hsv)

      IO.puts("      Splitting bands...")
      # Image.split_bands returns list directly, no {:ok, ...} 
      channels = Image.split_bands(hsv)
      IO.puts("      Got #{length(channels)} channels")

      sat_channel = Enum.at(channels, 1)
      IO.puts("      Getting average of saturation channel...")
      # Image.average returns list directly
      avg_result = Image.average(sat_channel)
      IO.puts("      Average result: #{inspect(avg_result)}")

      [avg_sat] = avg_result

      score = 1.0 - avg_sat / 255.0
      IO.puts("      Avg saturation: #{avg_sat}, Score: #{score}")
    rescue
      e -> IO.puts("      ❌ Saturation error: #{inspect(e)}")
    end
  end

  defp debug_histogram(image) do
    IO.puts("\n   📊 HISTOGRAM Analysis:")

    try do
      IO.puts("      Converting to grayscale...")
      {:ok, gray} = Image.to_colorspace(image, :bw)

      IO.puts("      Computing histogram...")
      # Use Vix.Vips.Operation.hist_find for actual pixel counts
      {:ok, histogram_image} = Operation.hist_find(gray)
      {width, height, bands} = Image.shape(histogram_image)
      IO.puts("      Histogram image shape: #{width}x#{height}x#{bands}")

      # Extract actual histogram values 
      histogram_values =
        for x <- 0..255 do
          case Operation.getpoint(histogram_image, x, 0) do
            {:ok, [value]} -> round(value)
            _ -> 0
          end
        end

      IO.puts("      First 10 values: #{Enum.take(histogram_values, 10) |> inspect()}")
      IO.puts("      Last 10 values: #{Enum.take(histogram_values, -10) |> inspect()}")

      dark_values = Enum.slice(histogram_values, 0, 50) |> Enum.sum()
      light_values = Enum.slice(histogram_values, 200, 56) |> Enum.sum()
      middle_values = Enum.slice(histogram_values, 50, 150) |> Enum.sum()
      total_pixels = Enum.sum(histogram_values)

      IO.puts("      Dark pixels (0-49): #{dark_values}")
      IO.puts("      Light pixels (200-254): #{light_values}")
      IO.puts("      Middle pixels (50-199): #{middle_values}")
      IO.puts("      Total pixels: #{total_pixels}")

      if total_pixels > 0 do
        bimodal_strength = (dark_values + light_values) / total_pixels
        middle_ratio = middle_values / total_pixels

        IO.puts("      Bimodal strength: #{bimodal_strength}")
        IO.puts("      Middle ratio: #{middle_ratio}")

        score =
          if middle_ratio < 0.3 and bimodal_strength > 0.6 do
            bimodal_strength
          else
            0.0
          end

        IO.puts("      Final bimodal score: #{score}")
      end
    rescue
      e -> IO.puts("      ❌ Histogram error: #{inspect(e)}")
    end
  end

  defp debug_edge_detection(image) do
    IO.puts("\n   ⚡ EDGE Analysis:")

    try do
      IO.puts("      Applying sharpen filter...")
      {:ok, sharpened} = Image.sharpen(image)

      IO.puts("      Getting original average...")
      # Image.average returns list directly
      original_bands = Image.average(image)
      IO.puts("      Original bands: #{inspect(original_bands)}")
      original_avg = Enum.sum(original_bands) / length(original_bands)
      IO.puts("      Original average: #{original_avg}")

      IO.puts("      Getting sharpened average...")
      sharpened_bands = Image.average(sharpened)
      IO.puts("      Sharpened bands: #{inspect(sharpened_bands)}")
      sharpened_avg = Enum.sum(sharpened_bands) / length(sharpened_bands)
      IO.puts("      Sharpened average: #{sharpened_avg}")

      edge_response = abs(sharpened_avg - original_avg) / 255.0
      score = min(edge_response * 3.0, 1.0)

      IO.puts("      Edge response: #{edge_response}")
      IO.puts("      Final edge score: #{score}")
    rescue
      e -> IO.puts("      ❌ Edge error: #{inspect(e)}")
    end
  end

  defp create_temp_file(page_data) do
    temp_path = Path.join([System.tmp_dir(), "basenji_verbose_debug_#{:rand.uniform(999_999)}.jpg"])
    File.write!(temp_path, page_data)
    temp_path
  end
end
