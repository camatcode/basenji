defmodule Basenji.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Basenji.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Basenji.Accounts.User

  defstruct users: nil

  @doc """
  Creates a scope for the given users.

  Returns nil if no users is given.
  """
  def for_users(%User{} = users) do
    %__MODULE__{users: users}
  end

  def for_users(nil), do: nil
end
