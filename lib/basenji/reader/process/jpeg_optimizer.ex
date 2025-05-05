defmodule Basenji.Reader.Process.JPEGOptimizer do
  @moduledoc false

  import Basenji.Reader
  # --size=1000 - only if size is > 1000
  # cat Bobby-Make-Believe_1915__0.jpg | jpegoptim --stdin --stdout --size=1000 > optim.jpg

  # opts - target_size_kb - a size target you want to hit
  def optimize_jpeg(bytes, opts \\ []) when is_binary(bytes) do
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
