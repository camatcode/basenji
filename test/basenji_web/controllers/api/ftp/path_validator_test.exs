defmodule BasenjiWeb.FTP.PathValidatorTest do
  use ExUnit.Case

  alias BasenjiWeb.FTP.PathValidator

  @moduletag :capture_log

  doctest PathValidator

  describe "valid_root_directory?/1" do
    test "validates all root paths" do
      valid_roots = [
        "/",
        "/comics",
        "/comics/",
        "/comics/by-id",
        "/comics/by-id/",
        "/comics/by-title",
        "/comics/by-title/",
        "/collections",
        "/collections/",
        "/collections/by-title",
        "/collections/by-title/"
      ]

      assert_valid(valid_roots)
    end

    test "validates paths with object references" do
      valid_paths = [
        "/comics/by-id/123",
        "/comics/by-title/batman",
        "/collections/by-title/456/comics/by-title/superman"
      ]

      assert_valid(valid_paths)
    end

    test "rejects invalid collection subpaths" do
      invalid_collection_subpaths = [
        "/collections/by-title/456/comics/invalid"
      ]

      assert_invalid(invalid_collection_subpaths)
    end

    test "rejects invalid paths" do
      invalid_paths = [
        "/invalid",
        "/totally/invalid/path",
        "/comics/invalid",
        "/collections/invalid"
      ]

      assert_invalid(invalid_paths)
    end
  end

  describe "parse_path/1" do
    test "returns single error atom for invalid paths" do
      invalid_paths = ["/invalid", "/totally/invalid"]
      Enum.each(invalid_paths, &assert_parse_error/1)
    end

    test "parses root paths" do
      assert_parse("/", path: "/", is_directory: true, subpath: nil)
      assert_parse("/comics", path: "/comics", is_directory: false, subpath: nil)
      assert_parse("/comics/by-id", path: "/comics/by-id", is_directory: false, subpath: nil)
    end

    test "extracts comic references" do
      assert_parse("/comics/by-id/123",
        path: "/comics/by-id/123",
        comic_id: "123",
        subpath: nil,
        is_directory: false
      )

      assert_parse("/comics/by-title/batman/",
        path: "/comics/by-title/batman/",
        comic_title: "batman",
        subpath: nil,
        is_directory: true
      )
    end

    test "extracts collection references" do
      assert_parse("/collections/by-title/456",
        path: "/collections/by-title/456",
        collection_title: "456",
        subpath: nil,
        is_directory: false
      )
    end

    test "extracts collection + comic references" do
      assert_parse("/collections/by-title/456/comics/by-id/123",
        collection_title: "456",
        comic_id: "123",
        subpath: nil
      )

      assert_parse("/collections/by-title/456/comics/by-title/batman",
        collection_title: "456",
        comic_title: "batman",
        subpath: nil
      )
    end

    test "extracts subpaths" do
      assert_parse("/comics/by-id/123/issue-1.cbz",
        comic_id: "123",
        subpath: "issue-1.cbz"
      )

      assert_parse("/collections/by-title/456/comics/by-title/batman/vol-1/issue-2.cbz",
        collection_title: "456",
        comic_title: "batman",
        subpath: "vol-1/issue-2.cbz"
      )
    end

    test "stops at first comic reference" do
      result =
        assert_parse("/collections/by-title/456/comics/by-id/123/comics/by-title/batman",
          collection_title: "456",
          comic_id: "123",
          subpath: "comics/by-title/batman"
        )

      refute Map.has_key?(result, :comic_title)
    end

    test "handles double slash normalization" do
      assert_parse("/comics//by-id//123//nested//path",
        path: "/comics//by-id//123//nested//path",
        comic_id: "123",
        subpath: "nested/path"
      )
    end

    test "detects directories vs files" do
      assert_parse("/comics/by-id/123/", is_directory: true)
      assert_parse("/comics/by-id/123", is_directory: false)
    end
  end

  defp assert_parse(path, expected_fields) do
    assert {:ok, result} = PathValidator.parse_path(path)

    Enum.each(expected_fields, fn {key, expected_value} ->
      actual_value = Map.get(result, key)

      assert actual_value == expected_value,
             "Expected #{key}: #{inspect(expected_value)}, got: #{inspect(actual_value)} for path: #{path}"
    end)

    result
  end

  defp assert_parse_error(path) do
    assert {:error, :invalid_path} = PathValidator.parse_path(path)
  end

  defp assert_valid(paths) when is_list(paths) do
    Enum.each(paths, &assert_valid/1)
  end

  defp assert_valid(path) do
    assert PathValidator.valid_root_directory?(path), "Expected #{path} to be valid"
  end

  defp assert_invalid(paths) when is_list(paths) do
    Enum.each(paths, &assert_invalid/1)
  end

  defp assert_invalid(path) do
    refute PathValidator.valid_root_directory?(path), "Expected #{path} to be invalid"
  end
end
