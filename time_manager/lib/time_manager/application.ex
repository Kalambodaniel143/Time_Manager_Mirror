defmodule TimeManager.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TimeManagerWeb.Telemetry,
      TimeManager.Repo,
      {DNSCluster, query: Application.get_env(:time_manager, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TimeManager.PubSub},
      # Start a worker by calling: TimeManager.Worker.start_link(arg)
      # {TimeManager.Worker, arg},
      # Start to serve requests, typically the last entry
      TimeManagerWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TimeManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TimeManagerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
