defmodule Basenji.Accounts do
  @moduledoc false

  use Basenji.TelemetryHelpers

  import Basenji.ContextUtils
  import Ecto.Query, warn: false

  alias Basenji.Accounts.APIToken
  alias Basenji.Accounts.User
  alias Basenji.Accounts.UserNotifier
  alias Basenji.Accounts.UserToken
  alias Basenji.Repo

  def register_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def list_users(opts \\ []) do
    meter_duration [:basenji, :query], "list_users" do
      opts = Keyword.merge([repo_opts: []], opts)

      User
      |> reduce_user_opts(opts)
      |> Repo.all(opts[:repo_opts])
    end
  end

  def get_user_by_email_and_password(email, password) when is_binary(email) and is_binary(password) do
    list_users(email: email)
    |> case do
      [user] -> if User.valid_password?(user, password), do: user
      _ -> nil
    end
  end

  def get_user(id, opts \\ []) do
    meter_duration [:basenji, :query], "get_user" do
      opts = Keyword.merge([repo_opts: []], opts)

      from(u in User, where: u.id == ^id)
      |> reduce_user_opts(opts)
      |> Repo.one(opts[:repo_opts])
      |> case do
        nil -> {:error, :not_found}
        result -> {:ok, result}
      end
    end
  end

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime),
    do: DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))

  def sudo_mode?(_user, _minutes), do: false

  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def login_user_by_magic_link(token) do
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

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  def deliver_login_instructions(%User{} = user, magic_link_url_fun) when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  def create_api_token(%User{} = user) do
    {token, user_token} = APIToken.build_api_token(user)
    Repo.insert!(user_token)
    token
  end

  def verify_api_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(APIToken.hash_algorithm(), decoded_token)

        from(t in APIToken,
          where: t.token == ^hashed_token and t.inserted_at > ago(365, "day"),
          join: user in assoc(t, :user),
          select: user
        )
        |> Repo.one()

      :error ->
        :error
    end
  end

  def delete_api_token(token) do
    from(t in APIToken,
      where: t.token == ^token
    )
    |> Repo.all()
    |> Enum.each(&Repo.delete(&1))
  end

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
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
