defmodule ConduitAmqp.Mixfile do
  use Mix.Project

  def project do
    [app: :conduit_amqp,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),

     description: "AMQP adapter for Conduit.",
     package: package]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :amqp, :poolboy]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:amqp, "~> 0.1"},
     {:amqp_client, github: "dsrosario/amqp_client", branch: "erlang_otp_19", override: true},
     {:connection, "~> 1.0"},
     {:poolboy, "~> 1.5"},
     {:conduit, "~> 0.1"}]
  end

  defp package do
    [# These are the default files included in the package
     name: :conduit_amqp,
     files: ["lib", "mix.exs", "README*", "LICENSE*"],
     maintainers: ["Allen Madsen"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/conduitframework/conduit_amqp",
              "Docs" => "https://hexdocs.pm/conduit_amqp"}]
  end
end
