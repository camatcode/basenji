defmodule BasenjiWeb.GraphQL.GraphQLUtils do
  @moduledoc """
  Utility functions for GraphQL resolvers
  """

  @doc """
  Handles common result patterns from context functions and converts them
  to appropriate GraphQL responses.
  """
  def handle_result(result) do
    case result do
      {:ok, data} -> {:ok, data}
      {:error, :not_found} -> {:error, "Not found"}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_changeset_errors(changeset)}
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "An error occurred"}
    end
  end

  def extract_preloads(info, field_mapping \\ %{}) do
    selections = get_selections(info)
    preloads = determine_preloads(selections, field_mapping)

    if Enum.empty?(preloads) do
      []
    else
      [preload: preloads]
    end
  end

  defp get_selections(%{definition: %{selections: selections}}) do
    selections
  end

  defp get_selections(_), do: []

  defp determine_preloads(selections, field_mapping) do
    selections
    |> Enum.filter(fn %{name: name} -> Map.has_key?(field_mapping, name) end)
    |> Enum.map(fn %{name: name} -> Map.get(field_mapping, name) end)
    |> Enum.reject(&is_nil/1)
  end

  defp format_changeset_errors(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map_join(", ", fn {field, {message, _}} -> "#{field}: #{message}" end)
  end
end
