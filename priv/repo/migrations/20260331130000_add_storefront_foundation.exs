defmodule Reseller.Repo.Migrations.AddStorefrontFoundation do
  use Ecto.Migration

  def change do
    create table(:storefronts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :title, :string, null: false
      add :tagline, :string
      add :description, :text
      add :theme_id, :string, null: false
      add :enabled, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:storefronts, [:user_id])
    create unique_index(:storefronts, [:slug])

    create table(:storefront_assets) do
      add :storefront_id, references(:storefronts, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :storage_key, :string, null: false
      add :content_type, :string, null: false
      add :original_filename, :string, null: false
      add :width, :integer
      add :height, :integer
      add :byte_size, :bigint
      add :checksum, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:storefront_assets, [:storefront_id, :kind])

    create constraint(
             :storefront_assets,
             :storefront_assets_kind_check,
             check: "kind IN ('logo', 'header')"
           )

    create table(:storefront_pages) do
      add :storefront_id, references(:storefronts, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :slug, :string, null: false
      add :menu_label, :string, null: false
      add :body, :text, null: false
      add :position, :integer, null: false, default: 1
      add :published, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:storefront_pages, [:storefront_id, :slug])
    create index(:storefront_pages, [:storefront_id, :position])

    create table(:storefront_inquiries) do
      add :storefront_id, references(:storefronts, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :nilify_all)
      add :full_name, :string, null: false
      add :contact, :string, null: false
      add :message, :text, null: false
      add :source_path, :string, null: false
      add :requester_ip, :string
      add :user_agent, :string

      timestamps(type: :utc_datetime)
    end

    create index(:storefront_inquiries, [:storefront_id, :inserted_at])
    create index(:storefront_inquiries, [:product_id, :inserted_at])

    alter table(:products) do
      add :storefront_enabled, :boolean, null: false, default: false
      add :storefront_published_at, :utc_datetime
    end

    create index(:products, [:user_id, :storefront_enabled, :status])

    alter table(:marketplace_listings) do
      add :external_url, :text
      add :external_url_added_at, :utc_datetime
    end
  end
end
