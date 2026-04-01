import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :reseller, Reseller.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "reseller_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :reseller, ResellerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "h2v8o0JtXpqWWjFF1v9JUTuaGvSNh5HB+OBp90ZP8eTBjrwBjtiJz08y0WF4v3EI",
  server: false

# In test we don't send emails
config :reseller, Reseller.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :reseller,
  password_hash_iterations: 1_000,
  api_token_ttl_days: 30

config :reseller, Reseller.AI, provider: Reseller.Support.Fakes.AIProvider

config :reseller, Reseller.AI.Providers.Gemini,
  api_key: "test-gemini-api-key",
  models: %{
    recognition: "gemini-test-recognition",
    description: "gemini-test-description",
    marketplace_listing: "gemini-test-marketplace",
    price_research: "gemini-test-pricing",
    reconciliation: "gemini-test-reconciliation",
    lifestyle_image: "gemini-test-lifestyle-image"
  }

config :reseller, Reseller.Search, provider: Reseller.Support.Fakes.SearchProvider

config :reseller, Reseller.Search.Providers.SerpApi, api_key: "test-serpapi-api-key"

config :reseller, Reseller.Media,
  storage: Reseller.Support.Fakes.MediaStorage,
  processor: Reseller.Support.Fakes.MediaProcessor,
  public_base_url: "https://cdn.example.test"

config :reseller, Reseller.Workers,
  processing_mode: :inline,
  product_processor: Reseller.Support.Fakes.ProductProcessor

config :reseller, Reseller.Exports,
  processing_mode: :inline,
  export_ttl_days: 7,
  builder: Reseller.Exports.ZipBuilder,
  notifier: Reseller.Support.Fakes.ExportNotifier,
  from_email: "exports@test.local"

config :reseller, Reseller.Imports, processing_mode: :inline

config :reseller, Reseller.Storefronts,
  notifier: Reseller.Support.Fakes.StorefrontNotifier,
  from_email: "storefront@test.local",
  inquiry_ip_limit: 5,
  inquiry_storefront_limit: 50,
  inquiry_window_minutes: 60
