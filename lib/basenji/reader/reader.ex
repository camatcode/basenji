defmodule Basenji.Reader do
  @callback get_entries(path :: String.t(), opts :: keyword()) ::
              {:ok, %{file_entries: [String.t()]}} | {:error, reason :: term}
end
