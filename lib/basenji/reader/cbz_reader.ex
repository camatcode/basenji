defmodule Basenji.Reader.CBZReader do
  @moduledoc false
  import Basenji.Reader

  def format, do: :cbz

  def get_magic_numbers, do: [%{offset: 0, magic: [0x50, 0x4B, 0x03, 0x04]}]

  # opts[:close] - will close the stream after reading
  def get_entries(cbz_file_path, opts \\ []) when is_bitstring(cbz_file_path) do
    with {:ok, unzip} <- open(cbz_file_path) do
      file_entries =
        Unzip.list_entries(unzip)
        |> sort_file_names()
        |> reject_macos_preview()
        |> reject_directories()

      if opts[:close] do
        close(unzip)
        {:ok, %{entries: file_entries, file: nil}}
      else
        {:ok, %{entries: file_entries, file: unzip}}
      end
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
    create_resource(fn -> Unzip.file_stream!(unzip, file_name, opts) end)
  end

  def open(cbz_file_path) when is_bitstring(cbz_file_path) do
    with true <- File.exists?(cbz_file_path) || {:error, "Doesn't exist, #{cbz_file_path}"},
         %Unzip.LocalFile{} = zip_file <- Unzip.LocalFile.open(cbz_file_path) do
      Unzip.new(zip_file)
    end
  end

  def read(cbz_file_path, opts \\ []) do
    with {:ok, %{entries: file_entries, file: unzip}} <- get_entries(cbz_file_path, opts) do
      file_entries =
        file_entries
        |> Enum.map(fn entry ->
          entry
          |> Map.put(:stream_fun, fn -> get_entry_stream!(unzip, entry, opts) end)
        end)

      {:ok, %{entries: file_entries, file: unzip}}
    end
  end

  def close(%Unzip{zip: %Unzip.LocalFile{} = zip_file}) do
    close(zip_file)
  end

  def close(%Unzip.LocalFile{} = zip_file) do
    Unzip.LocalFile.close(zip_file)
  end
end
