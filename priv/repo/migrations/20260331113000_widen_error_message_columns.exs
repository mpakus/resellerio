defmodule Reseller.Repo.Migrations.WidenErrorMessageColumns do
  use Ecto.Migration

  def change do
    alter table(:exports) do
      modify :error_message, :text, from: :string
    end

    alter table(:imports) do
      modify :error_message, :text, from: :string
    end
  end
end
