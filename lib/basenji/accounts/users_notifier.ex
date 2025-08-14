defmodule Basenji.Accounts.UsersNotifier do
  @moduledoc false
  import Swoosh.Email

  alias Basenji.Accounts.Users
  alias Basenji.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Basenji", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a users email.
  """
  def deliver_update_email_instructions(users, url) do
    deliver(users.email, "Update email instructions", """

    ==============================

    Hi #{users.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(users, url) do
    case users do
      %Users{confirmed_at: nil} -> deliver_confirmation_instructions(users, url)
      _ -> deliver_magic_link_instructions(users, url)
    end
  end

  defp deliver_magic_link_instructions(users, url) do
    deliver(users.email, "Log in instructions", """

    ==============================

    Hi #{users.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(users, url) do
    deliver(users.email, "Confirmation instructions", """

    ==============================

    Hi #{users.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
