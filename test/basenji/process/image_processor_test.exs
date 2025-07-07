defmodule Basenji.ImageProcessorTest do
  use Basenji.DataCase

  alias Basenji.Comics
  alias Basenji.ImageProcessor

  @moduletag :capture_log

  doctest ImageProcessor

  test "get_image_preview" do
    comic = insert(:comic)
    {:ok, bytes, _mime} = Comics.get_page(comic, 1)
    {:ok, preview_bytes} = ImageProcessor.get_image_preview(bytes, 600, 600)
    assert byte_size(preview_bytes) > 0
  end
end
