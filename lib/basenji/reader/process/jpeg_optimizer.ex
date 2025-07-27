defmodule Basenji.Reader.Process.JPEGOptimizer do
  @moduledoc false
  use Basenji.TelemetryHelpers

  import Basenji.Reader

  def optimize(jpeg_bytes, opts \\ [])

  def optimize(list, opts) when is_list(list) do
    :binary.list_to_bin(list) |> optimize(opts)
  end

  def optimize(<<0xFF, 0xD8, 0xFF, _::binary>> = jpeg_bytes, opts), do: optimize_impl(jpeg_bytes, opts)

  def optimize(not_jpeg_bytes, _) when is_binary(not_jpeg_bytes), do: {:ok, not_jpeg_bytes}

  def optimize!(jpeg_bytes, opts \\ []) do
    with {:ok, optimized_bytes} <- optimize(jpeg_bytes, opts) do
      optimized_bytes
    end
  end

  defp optimize_impl(bytes, _opts) when is_binary(bytes) do
    meter_duration [:basenji, :process], "optimize_jpeg" do
      # Use file-based approach in CI environments to avoid epipe issues
      # GitHub Actions and other CI systems can have issues with stdin/stdout pipes
      use_file_mode =
        System.get_env("CI") == "true" or
          System.get_env("GITHUB_ACTIONS") == "true" or
          System.get_env("BASENJI_JPEG_FILE_MODE") == "true"

      if use_file_mode do
        optimize_with_file(bytes)
      else
        # Try stdin first for local development (more efficient), fallback to file on error
        case optimize_with_stdin(bytes) do
          {:ok, result} -> {:ok, result}
          {:error, _} -> optimize_with_file(bytes)
        end
      end
    end
  end

  defp optimize_with_stdin(bytes) do
    cmd = "jpegoptim"
    cmd_opts = ["-f", "--stdout", "-q", "--stdin"]
    exec(cmd, cmd_opts, in: bytes)
  end

  defp optimize_with_file(bytes) do
    cmd = "jpegoptim"

    tmp_dir = System.tmp_dir!() |> Path.join("basenji") |> Path.join("jpeg_optimize")
    :ok = File.mkdir_p!(tmp_dir)
    path = Path.join(tmp_dir, "#{System.monotonic_time(:nanosecond)}.jpg")

    try do
      :ok = File.write!(path, bytes)
      cmd_opts = ["-f", "--stdout", "-q", path]
      exec(cmd, cmd_opts)
    after
      # Ensure cleanup even if exec fails
      File.rm(path)
    end
  end
end
