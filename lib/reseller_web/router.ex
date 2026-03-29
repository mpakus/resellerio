defmodule ResellerWeb.Router do
  use ResellerWeb, :router
  import Backpex.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug ResellerWeb.BrowserAuth, :fetch_current_user
    plug :put_root_layout, html: {ResellerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug ResellerWeb.Plugs.APIAuth
  end

  pipeline :browser_admin do
    plug ResellerWeb.BrowserAuth, :ensure_admin
  end

  scope "/", ResellerWeb do
    pipe_through :browser

    live_session :current_user, on_mount: [{ResellerWeb.LiveUserAuth, :mount_current_user}] do
      live "/", HomeLive
    end

    live_session :redirect_if_authenticated,
      on_mount: [{ResellerWeb.LiveUserAuth, :redirect_if_authenticated}] do
      live "/sign-up", Auth.SignUpLive
      live "/sign-in", Auth.SignInLive
    end

    live_session :authenticated, on_mount: [{ResellerWeb.LiveUserAuth, :ensure_authenticated}] do
      live "/app", WorkspaceLive
    end

    post "/sign-up", RegistrationController, :create
    post "/sign-in", SessionController, :create
    delete "/sign-out", SessionController, :delete
  end

  scope "/admin", ResellerWeb.Admin do
    pipe_through [:browser, :browser_admin]

    backpex_routes()
    get "/", RedirectController, :index

    live_session :admin,
      on_mount: [Backpex.InitAssigns, {ResellerWeb.LiveUserAuth, :ensure_admin}] do
      live_resources "/users", UserLive, only: [:index, :show, :edit]
      live_resources "/api-tokens", ApiTokenLive, only: [:index, :show]
    end
  end

  scope "/api", ResellerWeb do
    pipe_through :api

    scope "/v1", API.V1 do
      get "/", RootController, :show
      get "/health", HealthController, :show

      scope "/auth" do
        post "/register", AuthController, :register
        post "/login", AuthController, :login
      end
    end

    scope "/v1", API.V1 do
      pipe_through :api_authenticated

      get "/me", MeController, :show
      get "/products", ProductController, :index
      post "/products", ProductController, :create
      get "/products/:id", ProductController, :show
      post "/products/:id/finalize_uploads", ProductController, :finalize_uploads
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:reseller, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ResellerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
