defmodule BasenjiWeb.Accounts.LoginLive do
  use BasenjiWeb, :live_view

  alias Basenji.Accounts
  alias Swoosh.Adapters.Local

  def mount(_params, _session, socket) do
    socket
    |> assign_form()
    |> then(&{:ok, &1})
  end

  def handle_event("submit_password", _params, socket), do: {:noreply, assign(socket, :trigger_submit, true)}

  defp assign_form(socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")
    assign(socket, form: form, trigger_submit: false)
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm space-y-4">
      <div class="text-center">
        <.header>
          <p>Log in</p>
          <:subtitle>
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account? <.link
                navigate={~p"/users/register"}
                class="font-semibold text-brand hover:underline"
                phx-no-format
              >Sign up</.link> for an account now.
            <% end %>
          </:subtitle>
        </.header>
      </div>
      <.form
        :let={f}
        for={@form}
        id="login_form_password"
        action={~p"/users/log-in"}
        phx-submit="submit_password"
        phx-trigger-action={@trigger_submit}
      >
        <.input
          readonly={!!@current_scope}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.input
          field={@form[:password]}
          type="password"
          label="Password"
          autocomplete="current-password"
        />
        <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
          Log in
        </.button>
      </.form>
    </div>
    """
  end
end
