defmodule Basenji.Optimizer do
  @moduledoc false

  @callback optimize(bytes :: any(), opts :: list()) :: {:ok, any()} | {:error, any()}
  @callback optimize!(bytes :: any(), opts :: list()) :: any()
end
