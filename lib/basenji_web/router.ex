defmodule BasenjiWeb.Router do
  use BasenjiWeb, :router

  import Oban.Web.Router

  alias Absinthe.Plug.GraphiQL
  alias BasenjiWeb.GraphQL.Schema
  alias Plug.Swoosh.MailboxPreview

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BasenjiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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
    live "/comics", ComicsLive.Index, :index
    live "/comics/:id", ComicsLive.Show, :show
    live "/collections", CollectionsLive.Index, :index
    live "/collections/:id", CollectionsLive.Show, :show

    oban_dashboard("/oban")
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
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BasenjiWeb.Telemetry
      forward "/mailbox", MailboxPreview
    end
  end
end
