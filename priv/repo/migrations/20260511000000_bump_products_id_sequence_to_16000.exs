defmodule Reseller.Repo.Migrations.BumpProductsIdSequenceTo16000 do
  use Ecto.Migration

  def up do
    execute("""
    SELECT setval(
      pg_get_serial_sequence('products', 'id'),
      GREATEST(COALESCE((SELECT MAX(id) FROM products), 0), 15999),
      true
    )
    """)
  end

  def down do
    execute("""
    SELECT setval(
      pg_get_serial_sequence('products', 'id'),
      COALESCE((SELECT MAX(id) FROM products), 1),
      true
    )
    """)
  end
end
