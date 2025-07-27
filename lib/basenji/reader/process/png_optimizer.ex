defmodule Basenji.Reader.Process.PNGOptimizer do
  @moduledoc false
  use Basenji.TelemetryHelpers

  import Basenji.Reader

  def optimize(png_bytes, opts \\ [])

  def optimize(list, opts) when is_list(list) do
    :binary.list_to_bin(list) |> optimize(opts)
  end

  def optimize(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>> = png_bytes, _opts) do
    telemetry_wrap [:basenji, :process], %{action: "optimize_jpeg"} do
      cmd = "optipng"

      tmp_dir = System.tmp_dir!() |> Path.join("basenji") |> Path.join("png_optimize")
      :ok = File.mkdir_p!(tmp_dir)
      path = Path.join(tmp_dir, "#{System.monotonic_time(:nanosecond)}.jpg")

      try do
        :ok = File.write!(path, png_bytes)

        cmd_opts = ["-fix", "-quiet"] ++ [path]

        with {:ok, _} <- exec(cmd, cmd_opts) do
          {:ok, File.read!(path)}
        end
      after
        File.rm(path)
      end
    end
  end

  def optimize(not_png_bytes, _) when is_binary(not_png_bytes), do: {:ok, not_png_bytes}

  def optimize!(png_bytes, opts \\ []) do
    with {:ok, optimized_bytes} <- optimize(png_bytes, opts) do
      optimized_bytes
    end
  end
end
