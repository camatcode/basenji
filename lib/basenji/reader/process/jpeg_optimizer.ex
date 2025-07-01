defmodule Basenji.Reader.Process.JPEGOptimizer do
  @moduledoc false

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

  # opts - target_size_kb - a size target you want to hit
  defp optimize_impl(bytes, opts) when is_binary(bytes) do
    opts = Keyword.merge([target_size_kb: min(byte_size(bytes) / 1000, 1000)], opts)
    cmd = "jpegoptim"

    tmp_dir = System.tmp_dir!() |> Path.join("jpeg_optimize")
    :ok = File.mkdir_p!(tmp_dir)
    path = Path.join(tmp_dir, "#{System.monotonic_time(:nanosecond)}.jpg")

    try do
      :ok = File.write!(path, bytes)

      cmd_opts = ["-f", "--stdout", "-q"]

      cmd_opts =
        if opts[:target_size_kb],
          do: cmd_opts ++ ["--size=#{opts[:target_size_kb]}"],
          else: cmd_opts

      cmd_opts = cmd_opts ++ [path]
      exec(cmd, cmd_opts)
    after
      File.rm(path)
    end
  end
end
