defmodule Basenji.TelemetryHelpers do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      defmacro telemetry_wrap(event, metadata, do: block) do
        quote do
          start = System.monotonic_time()
          result = unquote(block)

          :telemetry.execute(unquote(event), %{duration: System.monotonic_time() - start}, unquote(metadata))

          result
        end
      end
    end
  end
end
