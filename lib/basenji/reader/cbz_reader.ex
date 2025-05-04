defmodule Basenji.Reader.CBZReader do
  @moduledoc false

  # opts[:close] - will close the stream after reading
  def get_entries(cbz_file_path, opts \\ []) when is_bitstring(cbz_file_path) do
    with {:ok, unzip} <- open(cbz_file_path) do
      file_entries =
        Unzip.list_entries(unzip)
        |> Enum.sort_by(& &1.file_name)
        |> Enum.filter(fn entry ->
          !String.contains?(entry.file_name, "__MACOSX") && entry.compressed_size != 0
        end)

      if opts[:close] do
        close(unzip)
        {:ok, %{entries: file_entries}}
      else
        {:ok, %{entries: file_entries, file: unzip}}
      end
    else
      non_matching -> {:error, non_matching}
    end
  end

  def get_entry_stream!(%Unzip{} = unzip, %Unzip.Entry{file_name: file_name}) do
    get_entry_stream!(unzip, file_name, [])
  end

  def get_entry_stream!(%Unzip{} = unzip, file_name) do
    get_entry_stream!(unzip, file_name, [])
  end

  # opts[:chunk_size] - Chunks are read from the source of the size specified by chunk_size.
  # 	This is not the size of the chunk returned by file_stream! since the chunk size varies after decompressing
  # 	the stream. Useful when reading from the source is expensive and you want optimize by increasing the chunk size.
  # 	 Defaults to 65_000
  def get_entry_stream!(%Unzip{} = unzip, %Unzip.Entry{file_name: file_name}, opts) do
    get_entry_stream!(unzip, file_name, opts)
  end

  def get_entry_stream!(%Unzip{} = unzip, file_name, opts) when is_bitstring(file_name) do
    Stream.resource(
      fn -> Unzip.file_stream!(unzip, file_name, opts) end,
      fn
        :halt -> {:halt, nil}
        func -> {func, :halt}
      end,
      fn _ -> nil end
    )
  end

  def open(cbz_file_path) when is_bitstring(cbz_file_path) do
    with true <- File.exists?(cbz_file_path) || {:err, "Doesn't exist, #{cbz_file_path}"},
         %Unzip.LocalFile{} = zip_file <- Unzip.LocalFile.open(cbz_file_path) do
      Unzip.new(zip_file)
    end
  end

  def read(cbz_file_path) do
    with {:ok, %{entries: file_entries, file: unzip}} <- get_entries(cbz_file_path) do
      file_entries =
        file_entries
        |> Enum.map(fn entry ->
          entry
          |> Map.put(:stream_fun, fn -> get_entry_stream!(unzip, entry) end)
        end)

      {:ok, %{entries: file_entries, file: unzip}}
    end
  end

  def close(%Unzip{
        zip: %Unzip.LocalFile{} = zip_file
      }) do
    close(zip_file)
  end

  def close(%Unzip.LocalFile{} = zip_file) do
    Unzip.LocalFile.close(zip_file)
  end
end
