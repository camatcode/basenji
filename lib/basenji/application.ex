defmodule Basenji.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BasenjiWeb.Telemetry,
      Basenji.Repo,
      {Oban, Application.fetch_env!(:basenji, Oban)},
      {DNSCluster, query: Application.get_env(:basenji, :dns_cluster_query) || :ignore},
      {Cachex, [:basenji_cache]},
      {Phoenix.PubSub, name: Basenji.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Basenji.Finch},
      # Start a worker by calling: Basenji.Worker.start_link(arg)
      # {Basenji.Worker, arg},
      # Start to serve requests, typically the last entry
      BasenjiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Basenji.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BasenjiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def get_comics_directory do
    Application.get_env(:basenji, :comics_dir, File.cwd!()) |> Path.expand()
  end
end
