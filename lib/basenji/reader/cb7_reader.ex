defmodule Basenji.Reader.CB7Reader do
  alias Porcelain.Result

  @spec get_entries(cbz_file_path :: String.t(), _opts :: keyword()) ::
          {:ok, %{entries: any()}} | {:error, any()}
  def get_entries(cbz_file_path, _opts \\ []) do
    with %Result{out: output, status: 0} <- Porcelain.exec("7z", ["l", "-ba", cbz_file_path]) do
      file_entries =
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(fn line ->
          String.slice(line, 53..-1//1)
        end)
        |> Enum.map(fn name -> %{file_name: "#{name}"} end)
        |> Enum.sort_by(& &1.file_name)
        |> Enum.filter(fn entry ->
          !String.contains?(entry.file_name, "__MACOSX")
        end)

      {:ok, %{entries: file_entries}}
    else
      non_matching -> {:error, non_matching}
    end
  end

  def get_entry_stream!(cbz_file_path, entry) do
    Stream.resource(
      fn ->
        with %Result{out: output, status: 0} <-
               Porcelain.exec("7z", ["x", "-so", cbz_file_path, entry[:file_name]]) do
          [output |> :binary.bin_to_list()]
        end
      end,
      fn
        :halt -> {:halt, nil}
        func -> {func, :halt}
      end,
      fn _ -> nil end
    )
  end

  def read(cbz_file_path, _opts \\ []) do
    with {:ok, %{entries: file_entries}} <- get_entries(cbz_file_path) do
      file_entries =
        file_entries
        |> Enum.map(fn entry ->
          entry
          |> Map.put(:stream_fun, fn -> get_entry_stream!(cbz_file_path, entry) end)
        end)

      {:ok, %{entries: file_entries}}
    end
  end
end
