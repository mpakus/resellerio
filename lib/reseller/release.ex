defmodule Reseller.Release do
  @moduledoc """
  Helpers for running database tasks in releases.
  """

  @app :reseller

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _migrated, _apps} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, :up, all: true)
        end)
    end
  end

  def rollback(repo, version) do
    load_app()

    {:ok, _rolled_back, _apps} =
      Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, :down, to: version)
      end)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
