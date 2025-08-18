defmodule BasenjiWeb.Accounts.SettingsLive do
  use BasenjiWeb, :live_view

  alias Basenji.Accounts
  alias Basenji.Accounts.User

  on_mount {BasenjiWeb.UserAuth, :require_sudo_mode}

  def mount(%{"token" => token}, _session, socket) do
    socket
    |> assign_flash(token)
    |> push_navigate(to: ~p"/users/settings")
    |> then(&{:ok, &1})
  end

  def mount(_params, _session, socket) do
    socket
    |> assign_user()
    |> then(&{:ok, &1})
  end

  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_changeset =
      socket.assigns.current_scope.user
      |> User.email_changeset(user_params, validate_unique: false)
      |> Map.put(:action, :validate)

    socket
    |> assign_user(email_changeset, nil)
    |> then(&{:noreply, &1})
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    # user_params
    case User.email_changeset(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_changeset =
      socket.assigns.current_scope.user
      |> User.password_changeset(user_params, hash_password: false)
      |> Map.put(:action, :validate)

    socket
    |> assign_user(nil, password_changeset)
    |> then(&{:noreply, &1})
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case User.password_changeset(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  defp assign_flash(socket, token) do
    case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
      {:ok, _user} ->
        put_flash(socket, :info, "Email changed successfully.")

      {:error, _} ->
        put_flash(socket, :error, "Email change link is invalid or it has expired.")
    end
  end

  defp assign_user(socket, email_changeset \\ nil, password_changeset \\ nil) do
    user = socket.assigns.current_scope.user
    email_changeset = email_changeset || User.email_changeset(user, %{}, validate_unique: false)
    password_changeset = password_changeset || User.password_changeset(user, %{}, hash_password: false)

    socket
    |> assign(:current_email, user.email)
    |> assign(:email_form, to_form(email_changeset))
    |> assign(:password_form, to_form(password_changeset))
    |> assign(:trigger_submit, false)
  end

  def render(assigns) do
    ~H"""
    <div class="text-center">
      <.header>
        Account Settings
        <:subtitle>Manage your account email address and password settings</:subtitle>
      </.header>
    </div>

    <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
      <.input
        field={@email_form[:email]}
        type="email"
        label="Email"
        autocomplete="username"
        required
      />
      <.button phx-disable-with="Changing...">Change Email</.button>
    </.form>

    <div class="divider" />

    <.form
      for={@password_form}
      id="password_form"
      action={~p"/users/update-password"}
      method="post"
      phx-change="validate_password"
      phx-submit="update_password"
      phx-trigger-action={@trigger_submit}
    >
      <input
        name={@password_form[:email].name}
        type="hidden"
        id="hidden_user_email"
        autocomplete="username"
        value={@current_email}
      />
      <.input
        field={@password_form[:password]}
        type="password"
        label="New password"
        autocomplete="new-password"
        required
      />
      <.input
        field={@password_form[:password_confirmation]}
        type="password"
        label="Confirm new password"
        autocomplete="new-password"
      />
      <.button phx-disable-with="Saving...">
        Save Password
      </.button>
    </.form>
    """
  end
end
