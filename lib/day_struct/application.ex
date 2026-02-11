defmodule DayStruct.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DayStructWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:day_struct, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DayStruct.PubSub},
      DayStruct.Store,
      DayStructWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DayStruct.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DayStructWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
