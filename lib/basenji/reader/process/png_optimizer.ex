defmodule Basenji.Reader.Process.PNGOptimizer do
  @moduledoc false

  import Basenji.Reader

  def optimize_png(bytes, _opts \\ []) when is_binary(bytes) do
    cmd = "optipng"

    tmp_dir = System.tmp_dir!() |> Path.join("png_optimize")
    :ok = File.mkdir_p!(tmp_dir)
    path = Path.join(tmp_dir, "#{System.monotonic_time(:nanosecond)}.jpg")

    try do
      :ok = File.write!(path, bytes)

      cmd_opts = ["-fix", "-quiet"] ++ [path]

      with {:ok, _} <- exec(cmd, cmd_opts) do
        {:ok, File.read!(path)}
      end
    after
      File.rm(path)
    end
  end
end
