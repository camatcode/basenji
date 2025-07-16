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

  defp optimize_impl(bytes, _opts) when is_binary(bytes) do
    cmd = "jpegoptim"
    cmd_opts = ["-f", "--stdout", "-q", "--stdin"]
    exec(cmd, cmd_opts, in: bytes)
  end
end
