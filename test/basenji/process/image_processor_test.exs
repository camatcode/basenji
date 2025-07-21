defmodule Basenji.ImageProcessorTest do
  use Basenji.DataCase

  alias Basenji.Comics
  alias Basenji.ImageProcessor

  @moduletag :capture_log

  doctest ImageProcessor

  test "get_image_preview" do
    comic = insert(:comic)
    {:ok, bytes, _mime} = Comics.get_page(comic, 1)
    {:ok, preview_bytes} = ImageProcessor.get_image_preview(bytes, 400, 600)
    assert byte_size(preview_bytes) > 0
  end

  test "resize" do
    comic = insert(:comic)
    {:ok, bytes, _mime} = Comics.get_page(comic, 1)

    original_byte_size = byte_size(bytes)
    original_img = Image.from_binary!(bytes)
    original_width = Image.width(original_img)
    original_height = Image.height(original_img)

    requested_width = 1920
    requested_height = 1080

    {:ok, resized_width_result} = ImageProcessor.resize_image(bytes, width: requested_width)
    assert original_byte_size != byte_size(resized_width_result)
    resized_w_img = Image.from_binary!(resized_width_result)
    assert Image.width(resized_w_img) == requested_width

    {:ok, resized_height_result} = ImageProcessor.resize_image(bytes, height: requested_height)
    assert original_byte_size != byte_size(resized_height_result)
    resized_h_img = Image.from_binary!(resized_height_result)
    assert Image.height(resized_h_img) == requested_height

    {:ok, forced_size_result} = ImageProcessor.resize_image(bytes, width: requested_width, height: requested_height)
    assert original_byte_size != byte_size(forced_size_result)
    forced_size_img = Image.from_binary!(forced_size_result)
    assert Image.width(forced_size_img) == requested_width
    assert Image.height(forced_size_img) == requested_height

    {:ok, noop} = ImageProcessor.resize_image(bytes)
    assert original_byte_size == byte_size(noop)
    noop_img = Image.from_binary!(noop)
    assert Image.width(noop_img) == original_width
    assert Image.height(noop_img) == original_height
  end
end
