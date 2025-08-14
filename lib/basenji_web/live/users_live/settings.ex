defmodule BasenjiWeb.UsersLive.Settings do
  use BasenjiWeb, :live_view

  alias Basenji.Accounts

  on_mount {BasenjiWeb.UsersAuth, :require_sudo_mode}

  @impl true
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
        id="hidden_users_email"
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

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_users_email(socket.assigns.current_scope.users, token) do
        {:ok, _users} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    users = socket.assigns.current_scope.users
    email_changeset = Accounts.change_users_email(users, %{}, validate_unique: false)
    password_changeset = Accounts.change_users_password(users, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, users.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"users" => users_params} = params

    email_form =
      socket.assigns.current_scope.users
      |> Accounts.change_users_email(users_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"users" => users_params} = params
    users = socket.assigns.current_scope.users
    true = Accounts.sudo_mode?(users)

    case Accounts.change_users_email(users, users_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_users_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          users.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"users" => users_params} = params

    password_form =
      socket.assigns.current_scope.users
      |> Accounts.change_users_password(users_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"users" => users_params} = params
    users = socket.assigns.current_scope.users
    true = Accounts.sudo_mode?(users)

    case Accounts.change_users_password(users, users_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
