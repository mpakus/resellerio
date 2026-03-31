defmodule Reseller.Repo.Migrations.AddProductSearchDocument do
  use Ecto.Migration

  def up do
    alter table(:products) do
      add :search_document, :tsvector
    end

    execute("""
    CREATE FUNCTION reseller_products_search_document_trigger()
    RETURNS trigger AS $$
    BEGIN
      NEW.search_document :=
        to_tsvector(
          'simple',
          coalesce(NEW.title, '') || ' ' ||
          coalesce(NEW.brand, '') || ' ' ||
          coalesce(NEW.category, '') || ' ' ||
          coalesce(NEW.condition, '') || ' ' ||
          coalesce(NEW.color, '') || ' ' ||
          coalesce(NEW.size, '') || ' ' ||
          coalesce(NEW.material, '') || ' ' ||
          coalesce(NEW.sku, '') || ' ' ||
          coalesce(NEW.notes, '') || ' ' ||
          coalesce(NEW.ai_summary, '') || ' ' ||
          coalesce(array_to_string(NEW.tags, ' '), '')
        );

      RETURN NEW;
    END
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER products_search_document_update
    BEFORE INSERT OR UPDATE OF title, brand, category, condition, color, size, material, sku, notes, ai_summary, tags
    ON products
    FOR EACH ROW
    EXECUTE FUNCTION reseller_products_search_document_trigger();
    """)

    execute("""
    UPDATE products
    SET search_document =
      to_tsvector(
        'simple',
        coalesce(title, '') || ' ' ||
        coalesce(brand, '') || ' ' ||
        coalesce(category, '') || ' ' ||
        coalesce(condition, '') || ' ' ||
        coalesce(color, '') || ' ' ||
        coalesce(size, '') || ' ' ||
        coalesce(material, '') || ' ' ||
        coalesce(sku, '') || ' ' ||
        coalesce(notes, '') || ' ' ||
        coalesce(ai_summary, '') || ' ' ||
        coalesce(array_to_string(tags, ' '), '')
      );
    """)

    create index(:products, [:search_document],
             using: :gin,
             name: :products_search_document_index
           )
  end

  def down do
    drop_if_exists index(:products, [:search_document], name: :products_search_document_index)

    execute("DROP TRIGGER IF EXISTS products_search_document_update ON products;")
    execute("DROP FUNCTION IF EXISTS reseller_products_search_document_trigger();")

    alter table(:products) do
      remove :search_document
    end
  end
end
