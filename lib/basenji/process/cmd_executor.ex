defmodule Basenji.CmdExecutor do
  @moduledoc false

  alias Porcelain.Result

  def exec(cmd, args, opts \\ []) do
    Porcelain.exec(cmd, args, opts)
    |> case do
      %Result{out: output, status: 0} ->
        {:ok, output |> String.trim()}

      other ->
        {:error, other}
    end
  end
end
