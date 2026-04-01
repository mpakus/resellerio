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

  pipeline :browser_authenticated do
    plug ResellerWeb.BrowserAuth, :ensure_authenticated
  end

  scope "/", ResellerWeb do
    pipe_through :browser

    get "/store/:slug", StorefrontController, :index
    get "/store/:slug/products/:product_ref", StorefrontController, :show_product
    get "/store/:slug/pages/:page_slug", StorefrontController, :show_page
    post "/store/:slug/products/:product_ref/inquiries", StorefrontController, :create_inquiry

    live_session :current_user, on_mount: [{ResellerWeb.LiveUserAuth, :mount_current_user}] do
      live "/", HomeLive
      live "/privacy", PrivacyLive
      live "/dpa", DPALive
    end

    live_session :redirect_if_authenticated,
      on_mount: [{ResellerWeb.LiveUserAuth, :redirect_if_authenticated}] do
      live "/sign-up", Auth.SignUpLive
      live "/sign-in", Auth.SignInLive
    end

    scope "/" do
      pipe_through :browser_authenticated

      get "/app/listings", WorkspaceRedirectController, :listings
      get "/app/products/export.xls", ProductsExcelController, :download
    end

    live_session :authenticated, on_mount: [{ResellerWeb.LiveUserAuth, :ensure_authenticated}] do
      live "/app", WorkspaceLive, :dashboard
      live "/app/products", ProductsLive.Index, :index
      live "/app/products/new", ProductsLive.New, :new
      live "/app/products/:id", ProductsLive.Show, :show
      live "/app/inquiries", InquiriesLive, :index
      live "/app/exports", WorkspaceLive, :exports
      live "/app/settings", WorkspaceLive, :settings
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
      live_resources "/products", ProductLive, only: [:index, :show, :edit]
      live_resources "/storefronts", StorefrontLive, only: [:index, :show, :edit]
      live_resources "/api-usage-events", ApiUsageEventLive, only: [:index, :show]
      live "/usage-dashboard", UsageDashboardLive
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
      patch "/me", MeController, :update
      get "/product_tabs", ProductTabController, :index
      post "/product_tabs", ProductTabController, :create
      patch "/product_tabs/:id", ProductTabController, :update
      delete "/product_tabs/:id", ProductTabController, :delete
      get "/storefront", StorefrontController, :show
      put "/storefront", StorefrontController, :upsert
      get "/storefront/pages", StorefrontController, :list_pages
      post "/storefront/pages", StorefrontController, :create_page
      patch "/storefront/pages/:page_id", StorefrontController, :update_page
      delete "/storefront/pages/:page_id", StorefrontController, :delete_page
      delete "/storefront/assets/:kind", StorefrontController, :delete_asset
      get "/inquiries", InquiryController, :index
      delete "/inquiries/:id", InquiryController, :delete
      get "/products", ProductController, :index
      post "/products", ProductController, :create
      get "/products/:id", ProductController, :show
      patch "/products/:id", ProductController, :update
      delete "/products/:id", ProductController, :delete
      post "/products/:id/finalize_uploads", ProductController, :finalize_uploads
      post "/products/:id/reprocess", ProductController, :reprocess

      post "/products/:id/generate_lifestyle_images",
           ProductController,
           :generate_lifestyle_images

      get "/products/:id/lifestyle_generation_runs", ProductController, :lifestyle_generation_runs

      post "/products/:id/generated_images/:image_id/approve",
           ProductController,
           :approve_generated_image

      delete "/products/:id/generated_images/:image_id",
             ProductController,
             :delete_generated_image

      delete "/products/:id/images/:image_id", ProductController, :delete_image

      post "/products/:id/mark_sold", ProductController, :mark_sold
      post "/products/:id/archive", ProductController, :archive
      post "/products/:id/unarchive", ProductController, :unarchive
      post "/exports", ExportController, :create
      get "/exports/:id", ExportController, :show
      post "/imports", ImportController, :create
      get "/imports/:id", ImportController, :show
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
