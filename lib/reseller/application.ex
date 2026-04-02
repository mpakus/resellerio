defmodule Reseller.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ResellerWeb.Telemetry,
      Reseller.Repo,
      {DNSCluster, query: Application.get_env(:reseller, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Reseller.PubSub},
      {Task.Supervisor, name: Reseller.Workers.TaskSupervisor},
      Reseller.Workers.ExpiryScheduler,
      # Start to serve requests, typically the last entry
      ResellerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Reseller.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ResellerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
