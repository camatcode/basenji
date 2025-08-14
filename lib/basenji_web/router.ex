defmodule BasenjiWeb.Router do
  use BasenjiWeb, :router
  use ErrorTracker.Web, :router

  import BasenjiWeb.UserAuth
  import Oban.Web.Router

  alias Absinthe.Plug.GraphiQL
  alias BasenjiWeb.GraphQL.Schema
  alias BasenjiWeb.Plugs.UserPresencePlug
  alias Plug.Swoosh.MailboxPreview

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BasenjiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :put_csp_headers
    plug UserPresencePlug
  end

  pipeline :browser_no_track do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BasenjiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_csp_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :json_api do
    plug :accepts, ["json", "json_api"]
  end

  scope "/", BasenjiWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/comics/:id/read", Comics.ReadLive, :show
  end

  scope "/admin" do
    pipe_through :browser_no_track

    oban_dashboard("/oban")
    error_tracker_dashboard("/errors")
  end

  scope "/api", BasenjiWeb do
    pipe_through :api
    get "/comics/:id/page/:page", ComicsController, :get_page
    get "/comics/:id/preview", ComicsController, :get_preview
  end

  # GraphQL API
  scope "/api" do
    pipe_through :api

    forward "/graphql", Absinthe.Plug, schema: Schema

    if Application.compile_env(:basenji, :dev_routes) do
      forward "/graphiql", GraphiQL,
        schema: Schema,
        interface: :simple
    end
  end

  # JSON:API
  scope "/api/json", BasenjiWeb.JSONAPI do
    pipe_through :json_api

    resources "/comics", ComicsController, only: [:index, :create, :show, :update, :delete]
    resources "/collections", CollectionsController, only: [:index, :create, :show, :update, :delete]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:basenji, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser_no_track
      live_dashboard "/dashboard", metrics: BasenjiWeb.Telemetry
      forward "/mailbox", MailboxPreview
    end
  end

  defp put_csp_headers(conn, _opts) do
    csp_directives = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob:",
      "font-src 'self'",
      "connect-src 'self'",
      "frame-ancestors 'none'"
    ]

    conn
    |> put_resp_header("content-security-policy", Enum.join(csp_directives, "; "))
  end

  ## Authentication routes

  scope "/", BasenjiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{BasenjiWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", BasenjiWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{BasenjiWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
