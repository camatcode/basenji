defmodule Basenji.TelemetryHelpers do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      defmacro meter_duration(event, action, do: block) do
        quote do
          start = System.monotonic_time()
          result = unquote(block)

          :telemetry.execute(unquote(event), %{duration: System.monotonic_time() - start}, %{action: unquote(action)})

          result
        end
      end
    end
  end
end
