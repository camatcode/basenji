defmodule Basenji.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  alias Basenji.Accounts.Users
  alias Basenji.Accounts.UsersNotifier
  alias Basenji.Accounts.UsersToken
  alias Basenji.Repo

  def get_users_by_email(email) when is_binary(email) do
    Repo.get_by(Users, email: email)
  end

  def get_users_by_email_and_password(email, password) when is_binary(email) and is_binary(password) do
    users = Repo.get_by(Users, email: email)
    if Users.valid_password?(users, password), do: users
  end

  def get_users!(id), do: Repo.get!(Users, id)

  def register_users(attrs) do
    %Users{}
    |> Users.email_changeset(attrs)
    |> Repo.insert()
  end

  def sudo_mode?(users, minutes \\ -20)

  def sudo_mode?(%Users{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_users, _minutes), do: false

  def change_users_email(users, attrs \\ %{}, opts \\ []) do
    Users.email_changeset(users, attrs, opts)
  end

  def update_users_email(users, token) do
    context = "change:#{users.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UsersToken.verify_change_email_token_query(token, context),
           %UsersToken{sent_to: email} <- Repo.one(query),
           {:ok, users} <- Repo.update(Users.email_changeset(users, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UsersToken, where: [users_id: ^users.id, context: ^context])) do
        {:ok, users}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  def change_users_password(users, attrs \\ %{}, opts \\ []) do
    Users.password_changeset(users, attrs, opts)
  end

  def update_users_password(users, attrs) do
    users
    |> Users.password_changeset(attrs)
    |> update_users_and_delete_all_tokens()
  end

  def generate_users_session_token(users) do
    {token, users_token} = UsersToken.build_session_token(users)
    Repo.insert!(users_token)
    token
  end

  def get_users_by_session_token(token) do
    {:ok, query} = UsersToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def get_users_by_magic_link_token(token) do
    with {:ok, query} <- UsersToken.verify_magic_link_token_query(token),
         {users, _token} <- Repo.one(query) do
      users
    else
      _ -> nil
    end
  end

  def login_users_by_magic_link(token) do
    {:ok, query} = UsersToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%Users{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%Users{confirmed_at: nil} = users, _token} ->
        users
        |> Users.confirm_changeset()
        |> update_users_and_delete_all_tokens()

      {users, token} ->
        Repo.delete!(token)
        {:ok, {users, []}}

      nil ->
        {:error, :not_found}
    end
  end

  def deliver_users_update_email_instructions(%Users{} = users, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, users_token} = UsersToken.build_email_token(users, "change:#{current_email}")

    Repo.insert!(users_token)
    UsersNotifier.deliver_update_email_instructions(users, update_email_url_fun.(encoded_token))
  end

  def deliver_login_instructions(%Users{} = users, magic_link_url_fun) when is_function(magic_link_url_fun, 1) do
    {encoded_token, users_token} = UsersToken.build_email_token(users, "login")
    Repo.insert!(users_token)
    UsersNotifier.deliver_login_instructions(users, magic_link_url_fun.(encoded_token))
  end

  def delete_users_session_token(token) do
    Repo.delete_all(from(UsersToken, where: [token: ^token, context: "session"]))
    :ok
  end

  defp update_users_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, users} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UsersToken, users_id: users.id)

        Repo.delete_all(from(t in UsersToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {users, tokens_to_expire}}
      end
    end)
  end
end
