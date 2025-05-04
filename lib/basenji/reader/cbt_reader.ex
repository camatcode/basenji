defmodule Basenji.Reader.CBTReader do
  @moduledoc false

  def get_entries(cbz_file_path, _opts \\ []) do
    with {:ok, names} <- :erl_tar.table(cbz_file_path, [:compressed]) do
      file_entries =
        names
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
    file_name = ~c"#{entry[:file_name]}"

    Stream.resource(
      fn ->
        with {:ok, [{^file_name, data}]} <-
               :erl_tar.extract(cbz_file_path, [
                 {:files, [file_name]},
                 :compressed,
                 :memory
               ]) do
          [data |> :binary.bin_to_list()]
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
