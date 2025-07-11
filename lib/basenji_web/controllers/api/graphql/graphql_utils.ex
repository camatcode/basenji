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

  defp format_changeset_errors(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map_join(", ", fn {field, {message, _}} -> "#{field}: #{message}" end)
  end
end
