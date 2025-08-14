defmodule BasenjiWeb.UsersLive.Registration do
  use BasenjiWeb, :live_view

  alias Basenji.Accounts
  alias Basenji.Accounts.Users

  @impl true
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

        <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
          Create an account
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{users: users}}} = socket) when not is_nil(users) do
    {:ok, redirect(socket, to: BasenjiWeb.UsersAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_users_email(%Users{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"users" => users_params}, socket) do
    case Accounts.register_users(users_params) do
      {:ok, users} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            users,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{users.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"users" => users_params}, socket) do
    changeset = Accounts.change_users_email(%Users{}, users_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "users")
    assign(socket, form: form)
  end
end
