defmodule Basenji.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Basenji.Accounts` context.
  """

  import Ecto.Query

  alias Basenji.Accounts
  alias Basenji.Accounts.Scope

  def unique_users_email, do: "users#{System.unique_integer()}@example.com"
  def valid_users_password, do: "hello world!"

  def valid_users_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_users_email()
    })
  end

  def unconfirmed_users_fixture(attrs \\ %{}) do
    {:ok, users} =
      attrs
      |> valid_users_attributes()
      |> Accounts.register_users()

    users
  end

  def users_fixture(attrs \\ %{}) do
    users = unconfirmed_users_fixture(attrs)

    token =
      extract_users_token(fn url ->
        Accounts.deliver_login_instructions(users, url)
      end)

    {:ok, {users, _expired_tokens}} =
      Accounts.login_users_by_magic_link(token)

    users
  end

  def users_scope_fixture do
    users = users_fixture()
    users_scope_fixture(users)
  end

  def users_scope_fixture(users) do
    Scope.for_users(users)
  end

  def set_password(users) do
    {:ok, {users, _expired_tokens}} =
      Accounts.update_users_password(users, %{password: valid_users_password()})

    users
  end

  def extract_users_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Basenji.Repo.update_all(
      from(t in Accounts.UsersToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_users_magic_link_token(users) do
    {encoded_token, users_token} = Accounts.UsersToken.build_email_token(users, "login")
    Basenji.Repo.insert!(users_token)
    {encoded_token, users_token.token}
  end

  def offset_users_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Basenji.Repo.update_all(
      from(ut in Accounts.UsersToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
