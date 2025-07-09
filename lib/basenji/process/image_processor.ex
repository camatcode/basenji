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
end
