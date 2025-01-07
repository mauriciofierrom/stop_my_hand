defmodule StopMyHand.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      StopMyHandWeb.Telemetry,
      # Start the Ecto repository
      StopMyHand.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: StopMyHand.PubSub},
      # Cache manager after Presence
      StopMyHand.Cache,
      # Start Finch
      {Finch, name: StopMyHand.Finch},
      # Start the Endpoint (http/https)
      StopMyHandWeb.Endpoint
      # Start a worker by calling: StopMyHand.Worker.start_link(arg)
      # {StopMyHand.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StopMyHand.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StopMyHandWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
