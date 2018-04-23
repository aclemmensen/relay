defmodule Relay.MixProject do
  use Mix.Project

  def project do
    [
      app: :relay,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.json": :test,
        "coveralls.detail": :test,
        credo: :test
      ],
      dialyzer: dialyzer(),
      elixirc_paths: ["lib", "gen"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Relay, []},
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      # Don't start application for tests.
      test: "test --no-start"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # 2018-04-23: grpc-elixir 0.3.0-alpha.2 has an issue that prevents us
      # sending messages to our servers:
      # https://github.com/tony612/grpc-elixir/issues/59
      {
        :grpc,
        git: "https://github.com/tony612/grpc-elixir.git",
        ref: "7353aa04cbf4cd982183aacd54d645fe6b4571dd"
      },
      {:google_protos, "~> 0.1"},
      {:httpoison, "~> 1.0"},
      # Hackney is a dependency of HTTPoison but had a bug in versions 1.10.0 to
      # 1.12.0 that caused deadlocks with async requests.
      {:hackney, ">= 1.12.1"},
      {:poison, "~> 3.1"},
      {:conform, "~> 2.2"},

      # Test deps.
      {
        :sse_test_server,
        git: "https://github.com/praekeltfoundation/sse_test_server.git",
        ref: "8f5373cdb4722b145e978fff4d4eb039072c655c",
        only: :test,
        app: false
      },
      {:excoveralls, "~> 0.8", only: :test},

      # Dev/test tools.
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:credo, "~> 0.9", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      # There are some warnings in the generated code that we don't control, so
      # we put them in the ignore file. The exact details of the warnings may
      # change when we regenerate the code, so the ignore file should be
      # updated to match.
      ignore_warnings: "dialyzer.ignore-warnings",
      # These are most of the optional warnings in the dialyzer docs. We skip
      # :error_handling (because we don't care about functions that only raise
      # exceptions) and two others that are intended for developing dialyzer
      # itself.
      flags: [
        :unmatched_returns,
        # The dialyzer docs indicate that the race condition check can
        # sometimes take a whole lot of time.
        :race_conditions,
        :underspecs
      ]
    ]
  end
end
