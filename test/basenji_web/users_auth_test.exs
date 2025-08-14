defmodule BasenjiWeb.UsersAuthTest do
  use BasenjiWeb.ConnCase, async: true

  import Basenji.AccountsFixtures

  alias Basenji.Accounts
  alias Basenji.Accounts.Scope
  alias BasenjiWeb.UsersAuth
  alias Phoenix.LiveView
  alias Phoenix.Socket.Broadcast

  @remember_me_cookie "_basenji_web_users_remember_me"
  @remember_me_cookie_max_age 60 * 60 * 24 * 14

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, BasenjiWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{users: %{users_fixture() | authenticated_at: DateTime.utc_now(:second)}, conn: conn}
  end

  describe "log_in_users/3" do
    test "stores the users token in the session", %{conn: conn, users: users} do
      conn = UsersAuth.log_in_users(conn, users)
      assert token = get_session(conn, :users_token)
      assert get_session(conn, :live_socket_id) == "users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_users_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, users: users} do
      conn = conn |> put_session(:to_be_removed, "value") |> UsersAuth.log_in_users(users)
      refute get_session(conn, :to_be_removed)
    end

    test "keeps session when re-authenticating", %{conn: conn, users: users} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_users(users))
        |> put_session(:to_be_removed, "value")
        |> UsersAuth.log_in_users(users)

      assert get_session(conn, :to_be_removed)
    end

    test "clears session when users does not match when re-authenticating", %{
      conn: conn,
      users: users
    } do
      other_users = users_fixture()

      conn =
        conn
        |> assign(:current_scope, Scope.for_users(other_users))
        |> put_session(:to_be_removed, "value")
        |> UsersAuth.log_in_users(users)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, users: users} do
      conn = conn |> put_session(:users_return_to, "/hello") |> UsersAuth.log_in_users(users)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, users: users} do
      conn = conn |> fetch_cookies() |> UsersAuth.log_in_users(users, %{"remember_me" => "true"})
      assert get_session(conn, :users_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :users_remember_me) == true

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :users_token)
      assert max_age == @remember_me_cookie_max_age
    end

    test "redirects to settings when users is already logged in", %{conn: conn, users: users} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_users(users))
        |> UsersAuth.log_in_users(users)

      assert redirected_to(conn) == ~p"/users/settings"
    end

    test "writes a cookie if remember_me was set in previous session", %{conn: conn, users: users} do
      conn = conn |> fetch_cookies() |> UsersAuth.log_in_users(users, %{"remember_me" => "true"})
      assert get_session(conn, :users_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :users_remember_me) == true

      conn =
        conn
        |> recycle()
        |> Map.replace!(:secret_key_base, BasenjiWeb.Endpoint.config(:secret_key_base))
        |> fetch_cookies()
        |> init_test_session(%{users_remember_me: true})

      # the conn is already logged in and has the remember_me cookie set,
      # now we log in again and even without explicitly setting remember_me,
      # the cookie should be set again
      conn = conn |> UsersAuth.log_in_users(users, %{})
      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :users_token)
      assert max_age == @remember_me_cookie_max_age
      assert get_session(conn, :users_remember_me) == true
    end
  end

  describe "logout_users/1" do
    test "erases session and cookies", %{conn: conn, users: users} do
      users_token = Accounts.generate_users_session_token(users)

      conn =
        conn
        |> put_session(:users_token, users_token)
        |> put_req_cookie(@remember_me_cookie, users_token)
        |> fetch_cookies()
        |> UsersAuth.log_out_users()

      refute get_session(conn, :users_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_users_by_session_token(users_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "users_sessions:abcdef-token"
      BasenjiWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> UsersAuth.log_out_users()

      assert_receive %Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if users is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> UsersAuth.log_out_users()
      refute get_session(conn, :users_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_scope_for_users/2" do
    test "authenticates users from session", %{conn: conn, users: users} do
      users_token = Accounts.generate_users_session_token(users)

      conn =
        conn |> put_session(:users_token, users_token) |> UsersAuth.fetch_current_scope_for_users([])

      assert conn.assigns.current_scope.users.id == users.id
      assert conn.assigns.current_scope.users.authenticated_at == users.authenticated_at
      assert get_session(conn, :users_token) == users_token
    end

    test "authenticates users from cookies", %{conn: conn, users: users} do
      logged_in_conn =
        conn |> fetch_cookies() |> UsersAuth.log_in_users(users, %{"remember_me" => "true"})

      users_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> UsersAuth.fetch_current_scope_for_users([])

      assert conn.assigns.current_scope.users.id == users.id
      assert conn.assigns.current_scope.users.authenticated_at == users.authenticated_at
      assert get_session(conn, :users_token) == users_token
      assert get_session(conn, :users_remember_me)

      assert get_session(conn, :live_socket_id) ==
               "users_sessions:#{Base.url_encode64(users_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, users: users} do
      _ = Accounts.generate_users_session_token(users)
      conn = UsersAuth.fetch_current_scope_for_users(conn, [])
      refute get_session(conn, :users_token)
      refute conn.assigns.current_scope
    end

    test "reissues a new token after a few days and refreshes cookie", %{conn: conn, users: users} do
      logged_in_conn =
        conn |> fetch_cookies() |> UsersAuth.log_in_users(users, %{"remember_me" => "true"})

      token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      offset_users_token(token, -10, :day)
      {users, _} = Accounts.get_users_by_session_token(token)

      conn =
        conn
        |> put_session(:users_token, token)
        |> put_session(:users_remember_me, true)
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> UsersAuth.fetch_current_scope_for_users([])

      assert conn.assigns.current_scope.users.id == users.id
      assert conn.assigns.current_scope.users.authenticated_at == users.authenticated_at
      assert new_token = get_session(conn, :users_token)
      assert new_token != token
      assert %{value: new_signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert new_signed_token != signed_token
      assert max_age == @remember_me_cookie_max_age
    end
  end

  describe "on_mount :mount_current_scope" do
    setup %{conn: conn} do
      %{conn: UsersAuth.fetch_current_scope_for_users(conn, [])}
    end

    test "assigns current_scope based on a valid users_token", %{conn: conn, users: users} do
      users_token = Accounts.generate_users_session_token(users)
      session = conn |> put_session(:users_token, users_token) |> get_session()

      {:cont, updated_socket} =
        UsersAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.users.id == users.id
    end

    test "assigns nil to current_scope assign if there isn't a valid users_token", %{conn: conn} do
      users_token = "invalid_token"
      session = conn |> put_session(:users_token, users_token) |> get_session()

      {:cont, updated_socket} =
        UsersAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end

    test "assigns nil to current_scope assign if there isn't a users_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        UsersAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_authenticated" do
    test "authenticates current_scope based on a valid users_token", %{conn: conn, users: users} do
      users_token = Accounts.generate_users_session_token(users)
      session = conn |> put_session(:users_token, users_token) |> get_session()

      {:cont, updated_socket} =
        UsersAuth.on_mount(:require_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.users.id == users.id
    end

    test "redirects to login page if there isn't a valid users_token", %{conn: conn} do
      users_token = "invalid_token"
      session = conn |> put_session(:users_token, users_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: BasenjiWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UsersAuth.on_mount(:require_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_scope == nil
    end

    test "redirects to login page if there isn't a users_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: BasenjiWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UsersAuth.on_mount(:require_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_sudo_mode" do
    test "allows users that have authenticated in the last 10 minutes", %{conn: conn, users: users} do
      users_token = Accounts.generate_users_session_token(users)
      session = conn |> put_session(:users_token, users_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: BasenjiWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:cont, _updated_socket} =
               UsersAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end

    test "redirects when authentication is too old", %{conn: conn, users: users} do
      eleven_minutes_ago = DateTime.utc_now(:second) |> DateTime.add(-11, :minute)
      users = %{users | authenticated_at: eleven_minutes_ago}
      users_token = Accounts.generate_users_session_token(users)
      {users, token_inserted_at} = Accounts.get_users_by_session_token(users_token)
      assert DateTime.after?(token_inserted_at, users.authenticated_at)
      session = conn |> put_session(:users_token, users_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: BasenjiWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, _updated_socket} =
               UsersAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end
  end

  describe "require_authenticated_users/2" do
    setup %{conn: conn} do
      %{conn: UsersAuth.fetch_current_scope_for_users(conn, [])}
    end

    test "redirects if users is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> UsersAuth.require_authenticated_users([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> UsersAuth.require_authenticated_users([])

      assert halted_conn.halted
      assert get_session(halted_conn, :users_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> UsersAuth.require_authenticated_users([])

      assert halted_conn.halted
      assert get_session(halted_conn, :users_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> UsersAuth.require_authenticated_users([])

      assert halted_conn.halted
      refute get_session(halted_conn, :users_return_to)
    end

    test "does not redirect if users is authenticated", %{conn: conn, users: users} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_users(users))
        |> UsersAuth.require_authenticated_users([])

      refute conn.halted
      refute conn.status
    end
  end

  describe "disconnect_sessions/1" do
    test "broadcasts disconnect messages for each token" do
      tokens = [%{token: "token1"}, %{token: "token2"}]

      for %{token: token} <- tokens do
        BasenjiWeb.Endpoint.subscribe("users_sessions:#{Base.url_encode64(token)}")
      end

      UsersAuth.disconnect_sessions(tokens)

      assert_receive %Broadcast{
        event: "disconnect",
        topic: "users_sessions:dG9rZW4x"
      }

      assert_receive %Broadcast{
        event: "disconnect",
        topic: "users_sessions:dG9rZW4y"
      }
    end
  end
end
