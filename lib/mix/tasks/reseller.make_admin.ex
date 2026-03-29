defmodule Mix.Tasks.Reseller.MakeAdmin do
  use Mix.Task

  @shortdoc "Grants admin access to an existing user by email"

  @impl Mix.Task
  def run([email]) do
    Mix.Task.run("app.start")

    case Reseller.Accounts.grant_admin_by_email(email) do
      {:ok, user} ->
        Mix.shell().info("Granted admin access to #{user.email}")

      {:error, :not_found} ->
        Mix.raise("No user found with email #{email}")

      {:error, changeset} ->
        Mix.raise("Could not grant admin access: #{inspect(changeset.errors)}")
    end
  end

  def run(_args) do
    Mix.raise("Usage: mix reseller.make_admin EMAIL")
  end
end
