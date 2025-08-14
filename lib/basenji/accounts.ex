defmodule Basenji.Accounts do
  @moduledoc false
  use Basenji.TelemetryHelpers

  import Basenji.ContextUtils
  import Ecto.Query, warn: false

  alias Basenji.Accounts.User
  alias Basenji.Accounts.UserNotifier
  alias Basenji.Accounts.UserToken
  alias Basenji.Repo

  def list_users(opts \\ []) do
    meter_duration [:basenji, :query], "list_users" do
      opts = Keyword.merge([repo_opts: []], opts)

      User
      |> reduce_user_opts(opts)
      |> Repo.all(opts[:repo_opts])
    end
  end

  def get_users_by_email_and_password(email, password) when is_binary(email) and is_binary(password) do
    users = Repo.get_by(User, email: email)
    if User.valid_password?(users, password), do: users
  end

  def get_users!(id), do: Repo.get!(User, id)

  def register_users(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  def sudo_mode?(users, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_users, _minutes), do: false

  def change_users_email(users, attrs \\ %{}, opts \\ []) do
    User.email_changeset(users, attrs, opts)
  end

  def update_users_email(users, token) do
    context = "change:#{users.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, users} <- Repo.update(User.email_changeset(users, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [users_id: ^users.id, context: ^context])) do
        {:ok, users}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  def change_users_password(users, attrs \\ %{}, opts \\ []) do
    User.password_changeset(users, attrs, opts)
  end

  def update_users_password(users, attrs) do
    users
    |> User.password_changeset(attrs)
    |> update_users_and_delete_all_tokens()
  end

  def generate_users_session_token(users) do
    {token, users_token} = UserToken.build_session_token(users)
    Repo.insert!(users_token)
    token
  end

  def get_users_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def get_users_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {users, _token} <- Repo.one(query) do
      users
    else
      _ -> nil
    end
  end

  def login_users_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = users, _token} ->
        users
        |> User.confirm_changeset()
        |> update_users_and_delete_all_tokens()

      {users, token} ->
        Repo.delete!(token)
        {:ok, {users, []}}

      nil ->
        {:error, :not_found}
    end
  end

  def deliver_users_update_email_instructions(%User{} = users, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, users_token} = UserToken.build_email_token(users, "change:#{current_email}")

    Repo.insert!(users_token)
    UserNotifier.deliver_update_email_instructions(users, update_email_url_fun.(encoded_token))
  end

  def deliver_login_instructions(%User{} = users, magic_link_url_fun) when is_function(magic_link_url_fun, 1) do
    {encoded_token, users_token} = UserToken.build_email_token(users, "login")
    Repo.insert!(users_token)
    UserNotifier.deliver_login_instructions(users, magic_link_url_fun.(encoded_token))
  end

  def delete_users_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  defp update_users_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, users} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, users_id: users.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {users, tokens_to_expire}}
      end
    end)
  end

  defp reduce_user_opts(query, opts) do
    {q, opts} = reduce_opts(query, opts)

    Enum.reduce(opts, q, fn
      {_any, ""}, query ->
        query

      {_any, nil}, query ->
        query

      {:email, email}, query ->
        where(query, [u], u.email == ^email)

      _, query ->
        query
    end)
  end
end
