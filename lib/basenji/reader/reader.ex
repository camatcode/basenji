defmodule Basenji.Reader do
  @moduledoc false

  alias Porcelain.Result

  def exec(cmd, args) do
    Porcelain.exec(cmd, args)
    |> case do
      %Result{out: output, status: 0} ->
        {:ok, output}

      other ->
        {:error, other}
    end
  end

  def create_resource(make_func) do
    Stream.resource(
      make_func,
      fn
        :halt -> {:halt, nil}
        func -> {func, :halt}
      end,
      fn _ -> nil end
    )
  end

  def sort_file_names(e), do: Enum.sort_by(e, & &1.file_name)

  def reject_macos_preview(e), do: Enum.reject(e, &String.contains?(&1.file_name, "__MACOSX"))
end
