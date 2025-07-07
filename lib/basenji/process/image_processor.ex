defmodule Basenji.ImageProcessor do
  @moduledoc false

  def get_image_preview(binary, preview_width_target, preview_height_target) do
    with {:ok, image} <- Image.from_binary(binary),
         {:ok, preview} <- Image.thumbnail(image, "#{preview_width_target}x#{preview_height_target}", fit: :contain) do
      Image.write(preview, :memory, suffix: ".jpg")
    end
  end
end
