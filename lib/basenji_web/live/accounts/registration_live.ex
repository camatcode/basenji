defmodule BasenjiWeb.Accounts.RegistrationLive do
  use BasenjiWeb, :live_view

  alias Basenji.Accounts
  alias Basenji.Accounts.User

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket) when not is_nil(user),
    do: {:ok, redirect(socket, to: BasenjiWeb.UserAuth.signed_in_path(socket))}

  def mount(_params, _session, socket) do
    {:ok, assign_form(socket), temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    user_params = Map.put(user_params, "confirmed_at", DateTime.utc_now())

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        IO.inspect(user)

        socket
        |> push_navigate(to: ~p"/users/log-in")
        |> then(&{:noreply, &1})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = User.email_changeset(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket), do: assign_form(socket, User.email_changeset(%User{}, %{}, validate_unique: false))

  defp assign_form(socket, %Ecto.Changeset{} = changeset), do: assign(socket, form: to_form(changeset, as: "user"))

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <div class="text-center">
        <.header>
          Register for an account
          <:subtitle>
            Already registered?
            <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
              Log in
            </.link>
            to your account now.
          </:subtitle>
        </.header>
      </div>

      <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
          phx-mounted={JS.focus()}
        />

        <.input
          field={@form[:password]}
          type="password"
          label="Password"
          autocomplete="password"
          required
          phx-mounted={JS.focus()}
        />

        <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
          Create an account
        </.button>
      </.form>
    </div>
    """
  end
end
