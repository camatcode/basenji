defmodule BasenjiWeb.UsersLive.ConfirmationTest do
  use BasenjiWeb.ConnCase, async: true

  import Basenji.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Basenji.Accounts

  setup do
    %{unconfirmed_users: unconfirmed_users_fixture(), confirmed_users: users_fixture()}
  end

  describe "Confirm users" do
    test "renders confirmation page for unconfirmed users", %{conn: conn, unconfirmed_users: users} do
      token =
        extract_users_token(fn url ->
          Accounts.deliver_login_instructions(users, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      assert html =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed users", %{conn: conn, confirmed_users: users} do
      token =
        extract_users_token(fn url ->
          Accounts.deliver_login_instructions(users, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_users: users} do
      token =
        extract_users_token(fn url ->
          Accounts.deliver_login_instructions(users, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"users" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Users confirmed successfully"

      assert Accounts.get_users!(users.id).confirmed_at
      # we are logged in now
      assert get_session(conn, :users_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "logs confirmed users in without changing confirmed_at", %{
      conn: conn,
      confirmed_users: users
    } do
      token =
        extract_users_token(fn url ->
          Accounts.deliver_login_instructions(users, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#login_form", %{"users" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert Accounts.get_users!(users.id).confirmed_at == users.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/invalid-token")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end
end
