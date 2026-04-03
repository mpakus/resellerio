defmodule Reseller.Repo.Migrations.BumpCoreSequences do
  use Ecto.Migration

  def up do
    bump_sequence("users", 999)
    bump_sequence("storefronts", 999)
    bump_sequence("product_tabs", 1499)
    bump_sequence("imports", 999)
    bump_sequence("exports", 999)
    bump_sequence("api_tokens", 999)
  end

  def down do
    reset_sequence("users")
    reset_sequence("storefronts")
    reset_sequence("product_tabs")
    reset_sequence("imports")
    reset_sequence("exports")
    reset_sequence("api_tokens")
  end

  defp bump_sequence(table, minimum_last_value) do
    execute("""
    SELECT setval(
      pg_get_serial_sequence('#{table}', 'id'),
      GREATEST(COALESCE((SELECT MAX(id) FROM #{table}), 0), #{minimum_last_value}),
      true
    )
    """)
  end

  defp reset_sequence(table) do
    execute("""
    SELECT setval(
      pg_get_serial_sequence('#{table}', 'id'),
      COALESCE((SELECT MAX(id) FROM #{table}), 1),
      true
    )
    """)
  end
end
