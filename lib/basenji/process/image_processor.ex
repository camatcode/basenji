defmodule Basenji.ImageProcessor do
  @moduledoc false

  alias Basenji.Reader.Process.JPEGOptimizer

  def get_image_preview(binary, preview_width_target, preview_height_target) do
    with {:ok, image} <- Image.from_binary(binary),
         {:ok, preview} <- Image.thumbnail(image, "#{preview_width_target}x#{preview_height_target}", fit: :contain) do
      bytes =
        Image.write!(preview, :memory, suffix: ".jpg")
        |> JPEGOptimizer.optimize!()

      {:ok, bytes}
    end
  end

  def resize_image(binary, opts \\ []) when is_binary(binary) do
    if Keyword.has_key?(opts, :width) || Keyword.has_key?(opts, :height) do
      with {:ok, image} <- Image.from_binary(binary) do
        {original_width, original_height} = {Image.width(image), Image.height(image)}
        {scale, options} = calculate_resize_opts(original_width, original_height, opts)
        {:ok, resized} = Image.resize(image, scale, options)

        {:ok, Image.write!(resized, :memory, suffix: ".jpg")}
      end
    else
      {:ok, binary}
    end
  end

  defp calculate_resize_opts(start_width, start_height, width: width, height: height) do
    horizontal_scale = width / start_width
    vertical_scale = height / start_height
    {horizontal_scale, [vertical_scale: vertical_scale]}
  end

  defp calculate_resize_opts(start_width, _start_height, width: width), do: {width / start_width, []}
  defp calculate_resize_opts(_start_width, start_height, height: height), do: {height / start_height, []}
end
