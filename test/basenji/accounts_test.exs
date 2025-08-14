defmodule Basenji.AccountsTest do
  use Basenji.DataCase

  import Basenji.AccountsFixtures

  alias Basenji.Accounts
  alias Basenji.Accounts.{User, UserToken}

  describe "get_users_by_email/1" do
    test "does not return the users if the email does not exist" do
      assert Enum.empty?(Accounts.list_users(email: "unknown@example.com"))
    end

    test "returns the users if the email exists" do
      %{id: id} = users = users_fixture()
      assert [%User{id: ^id}] = Accounts.list_users(email: users.email)
    end
  end

  describe "get_users_by_email_and_password/2" do
    test "does not return the users if the email does not exist" do
      refute Accounts.get_users_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the users if the password is not valid" do
      users = users_fixture() |> set_password()
      refute Accounts.get_users_by_email_and_password(users.email, "invalid")
    end

    test "returns the users if the email and password are valid" do
      %{id: id} = users = users_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_users_by_email_and_password(users.email, valid_users_password())
    end
  end

  describe "get_users!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_users!(-1)
      end
    end

    test "returns the users with the given id" do
      %{id: id} = users = users_fixture()
      assert %User{id: ^id} = Accounts.get_users!(users.id)
    end
  end

  describe "register_users/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_users(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_users(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_users(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = users_fixture()
      {:error, changeset} = Accounts.register_users(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_users(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = unique_users_email()
      {:ok, users} = Accounts.register_users(valid_users_attributes(email: email))
      assert users.email == email
      assert is_nil(users.hashed_password)
      assert is_nil(users.confirmed_at)
      assert is_nil(users.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_users_email/3" do
    test "returns a users changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_users_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_users_update_email_instructions/3" do
    setup do
      %{users: users_fixture()}
    end

    test "sends token through notification", %{users: users} do
      token =
        extract_users_token(fn url ->
          Accounts.deliver_users_update_email_instructions(users, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert users_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert users_token.users_id == users.id
      assert users_token.sent_to == users.email
      assert users_token.context == "change:current@example.com"
    end
  end

  describe "update_users_email/2" do
    setup do
      users = unconfirmed_users_fixture()
      email = unique_users_email()

      token =
        extract_users_token(fn url ->
          Accounts.deliver_users_update_email_instructions(%{users | email: email}, users.email, url)
        end)

      %{users: users, token: token, email: email}
    end

    test "updates the email with a valid token", %{users: users, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_users_email(users, token)
      changed_users = Repo.get!(User, users.id)
      assert changed_users.email != users.email
      assert changed_users.email == email
      refute Repo.get_by(UserToken, users_id: users.id)
    end

    test "does not update email with invalid token", %{users: users} do
      assert Accounts.update_users_email(users, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, users.id).email == users.email
      assert Repo.get_by(UserToken, users_id: users.id)
    end

    test "does not update email if users email changed", %{users: users, token: token} do
      assert Accounts.update_users_email(%{users | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, users.id).email == users.email
      assert Repo.get_by(UserToken, users_id: users.id)
    end

    test "does not update email if token expired", %{users: users, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_users_email(users, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, users.id).email == users.email
      assert Repo.get_by(UserToken, users_id: users.id)
    end
  end

  describe "change_users_password/3" do
    test "returns a users changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_users_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_users_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_users_password/2" do
    setup do
      %{users: users_fixture()}
    end

    test "validates password", %{users: users} do
      {:error, changeset} =
        Accounts.update_users_password(users, %{
          password: "not",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 5 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{users: users} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_users_password(users, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{users: users} do
      {:ok, {users, expired_tokens}} =
        Accounts.update_users_password(users, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(users.password)
      assert Accounts.get_users_by_email_and_password(users.email, "new valid password")
    end

    test "deletes all tokens for the given users", %{users: users} do
      _ = Accounts.generate_users_session_token(users)

      {:ok, {_, _}} =
        Accounts.update_users_password(users, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, users_id: users.id)
    end
  end

  describe "generate_users_session_token/1" do
    setup do
      %{users: users_fixture()}
    end

    test "generates a token", %{users: users} do
      token = Accounts.generate_users_session_token(users)
      assert users_token = Repo.get_by(UserToken, token: token)
      assert users_token.context == "session"
      assert users_token.authenticated_at != nil

      # Creating the same token for another users should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: users_token.token,
          users_id: users_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given users in new token", %{users: users} do
      users = %{users | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_users_session_token(users)
      assert users_token = Repo.get_by(UserToken, token: token)
      assert users_token.authenticated_at == users.authenticated_at
      assert DateTime.after?(users_token.inserted_at, users.authenticated_at)
    end
  end

  describe "get_users_by_session_token/1" do
    setup do
      users = users_fixture()
      token = Accounts.generate_users_session_token(users)
      %{users: users, token: token}
    end

    test "returns users by token", %{users: users, token: token} do
      assert {session_users, token_inserted_at} = Accounts.get_users_by_session_token(token)
      assert session_users.id == users.id
      assert session_users.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return users for invalid token" do
      refute Accounts.get_users_by_session_token("oops")
    end

    test "does not return users for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_users_by_session_token(token)
    end
  end

  describe "get_users_by_magic_link_token/1" do
    setup do
      users = users_fixture()
      {encoded_token, _hashed_token} = generate_users_magic_link_token(users)
      %{users: users, token: encoded_token}
    end

    test "returns users by token", %{users: users, token: token} do
      assert session_users = Accounts.get_users_by_magic_link_token(token)
      assert session_users.id == users.id
    end

    test "does not return users for invalid token" do
      refute Accounts.get_users_by_magic_link_token("oops")
    end

    test "does not return users for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_users_by_magic_link_token(token)
    end
  end

  describe "login_users_by_magic_link/1" do
    test "confirms users and expires tokens" do
      users = unconfirmed_users_fixture()
      refute users.confirmed_at
      {encoded_token, hashed_token} = generate_users_magic_link_token(users)

      assert {:ok, {users, [%{token: ^hashed_token}]}} =
               Accounts.login_users_by_magic_link(encoded_token)

      assert users.confirmed_at
    end

    test "returns users and (deleted) token for confirmed users" do
      users = users_fixture()
      assert users.confirmed_at
      {encoded_token, _hashed_token} = generate_users_magic_link_token(users)
      assert {:ok, {^users, []}} = Accounts.login_users_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_users_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed users has password set" do
      users = unconfirmed_users_fixture()
      {1, nil} = Repo.update_all(User, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_users_magic_link_token(users)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_users_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_users_session_token/1" do
    test "deletes the token" do
      users = users_fixture()
      token = Accounts.generate_users_session_token(users)
      assert Accounts.delete_users_session_token(token) == :ok
      refute Accounts.get_users_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{users: unconfirmed_users_fixture()}
    end

    test "sends token through notification", %{users: users} do
      token =
        extract_users_token(fn url ->
          Accounts.deliver_login_instructions(users, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert users_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert users_token.users_id == users.id
      assert users_token.sent_to == users.email
      assert users_token.context == "login"
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
