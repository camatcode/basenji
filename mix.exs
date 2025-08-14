defmodule Basenji.MixProject do
  use Mix.Project

  @source_url "https://github.com/camatcode/basenji"
  @version "0.9.0"
  @doc_logo_location "assets/basenji-logo.svg"

  def project do
    [
      app: :basenji,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ],
      listeners: [Phoenix.CodeReloader],
      releases: [basenji: [applications: [basenji: :permanent]]],

      # Hex
      package: package(),
      description: """
      A modern, self-hostable comic/e-book reader
      """,

      # Docs
      name: "Basenji",
      docs: [
        main: "Basenji",
        api_reference: false,
        logo: @doc_logo_location,
        source_ref: "v#{@version}",
        source_url: @source_url,
        extra_section: "GUIDES",
        extras: extras(),
        formatters: ["html"],
        extras: extras(),
        groups_for_modules: groups_for_modules(),
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Basenji.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon, :porcelain]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp groups_for_modules do
    []
  end

  def package do
    [
      maintainers: ["Cam Cook"],
      licenses: ["Apache-2.0"],
      files: ~w(lib .formatter.exs mix.exs README* CHANGELOG* LICENSE*),
      links: %{
        Website: @source_url,
        Changelog: "#{@source_url}/blob/master/CHANGELOG.md",
        GitHub: @source_url
      }
    ]
  end

  def extras do
    [
      "README.md"
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      # general deps
      {:tidewave, "~> 0.2", only: :dev},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:ex_license, "~> 0.1", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:faker, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.8", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test]},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:telemetry_metrics_statsd, "~> 0.7"},
      {:error_tracker, "~> 0.6"},
      {:ecto_psql_extras, "~> 0.6"},
      {:prom_ex, "~> 1.11.0"},
      # api deps
      {:jsonapi_plug, "~> 2.0"},
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},
      {:ex_ftp, "~> 1.0"},
      # basenji deps
      {:oban, "~> 2.19"},
      {:oban_web, "~> 2.11"},
      {:image, "~> 0.61"},
      {:proper_case, "~> 1.3"},
      {:date_time_parser, "~> 1.2"},
      {:xxh3, "~> 0.3"},
      {:zarex, "~> 1.0"},
      {:cachex, "~> 4.1"},
      # phx deps
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3.1", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons", tag: "v2.2.0", sparse: "optimized", app: false, compile: false, depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      # reader deps
      {:zstream, "~> 0.6"},
      {:unzip, "~> 0.12"},
      {:porcelain, "~> 2.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind basenji", "esbuild basenji"],
      "assets.deploy": [
        "tailwind basenji --minify",
        "esbuild basenji --minify",
        "phx.digest"
      ]
    ]
  end
end
