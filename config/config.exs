# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :reseller,
  ecto_repos: [Reseller.Repo],
  generators: [timestamp_type: :utc_datetime],
  password_hash_iterations: 100_000,
  api_token_ttl_days: 30

config :reseller, Reseller.AI,
  provider: Reseller.AI.Providers.Gemini,
  lifestyle_generation_enabled: false

config :reseller, Reseller.AI.Providers.Gemini,
  base_url: "https://generativelanguage.googleapis.com/v1beta",
  timeout: 45_000,
  max_retries: 1,
  retry_backoff_ms: 750,
  models: %{
    recognition: "gemini-2.5-flash",
    description: "gemini-2.5-flash",
    marketplace_listing: "gemini-2.5-flash",
    price_research: "gemini-2.5-flash",
    reconciliation: "gemini-2.5-flash",
    lifestyle_image: "gemini-2.5-flash-image"
  }

config :reseller, Reseller.Search, provider: Reseller.Search.Providers.SerpApi

config :reseller, Reseller.Search.Providers.SerpApi,
  base_url: "https://serpapi.com/search",
  shopping_engine: "google_shopping_light",
  default_language: "en",
  default_country: "us",
  timeout: 10_000

config :reseller, Reseller.Media,
  storage: Reseller.Media.Storage.Tigris,
  processor: Reseller.Media.Processors.Photoroom

config :reseller, Reseller.Media.Processors.Photoroom,
  base_url: "https://image-api.photoroom.com/v2/edit",
  timeout: 15_000,
  padding: 0.15,
  output_format: "png"

config :reseller, Reseller.Media.Storage.Tigris,
  region: "auto",
  expires_in: 900

config :ex_aws,
  http_client: ExAws.Request.Req,
  json_codec: Jason

config :ex_aws, :req_opts, receive_timeout: 30_000

config :reseller, Reseller.Workers,
  processing_mode: :async,
  product_processor: Reseller.Workers.AIProductProcessor

config :reseller, Reseller.Marketplaces,
  supported_marketplaces: ~w(
      ebay
      depop
      poshmark
      mercari
      facebook_marketplace
      offerup
      whatnot
      grailed
      therealreal
      vestiaire_collective
      thredup
      etsy
    ),
  default_marketplaces: ~w(ebay depop poshmark)

config :reseller, Reseller.Exports,
  processing_mode: :async,
  export_ttl_days: 7,
  builder: Reseller.Exports.ZipBuilder,
  notifier: Reseller.Exports.Notifiers.Email,
  from_email: "exports@resellerio.local"

config :reseller, Reseller.Imports, processing_mode: :async

config :reseller, Reseller.Storefronts,
  notifier: Reseller.Storefronts.Notifiers.Email,
  from_email: "storefront@resellerio.local",
  inquiry_ip_limit: 5,
  inquiry_storefront_limit: 50,
  inquiry_window_minutes: 60

config :backpex,
  pubsub_server: Reseller.PubSub,
  translator_function: {ResellerWeb.CoreComponents, :translate_backpex},
  error_translator_function: {ResellerWeb.CoreComponents, :translate_error}

# Configures the endpoint
config :reseller, ResellerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ResellerWeb.ErrorHTML, json: ResellerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Reseller.PubSub,
  live_view: [signing_salt: "297qJ0fM"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :reseller, Reseller.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  reseller: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  reseller: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
