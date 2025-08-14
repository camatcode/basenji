defmodule BasenjiWeb.UsersSessionController do
  use BasenjiWeb, :controller

  alias Basenji.Accounts
  alias BasenjiWeb.UsersAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "Users confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = users_params}, info) do
    case Accounts.login_users_by_magic_link(token) do
      {:ok, {users, tokens_to_disconnect}} ->
        UsersAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UsersAuth.log_in_users(users, users_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"user" => users_params}, info) do
    %{"email" => email, "password" => password} = users_params

    if users = Accounts.get_users_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UsersAuth.log_in_users(users, users_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => users_params} = params) do
    users = conn.assigns.current_scope.users
    true = Accounts.sudo_mode?(users)
    {:ok, {_users, expired_tokens}} = Accounts.update_users_password(users, users_params)

    # disconnect all existing LiveViews with old sessions
    UsersAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:users_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UsersAuth.log_out_users()
  end
end
