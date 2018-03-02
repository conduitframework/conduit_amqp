# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

if Mix.env() == :test do
  config :conduit, ConduitAMQPTest, url: System.get_env("AMQP_URL") || "amqp://guest:guest@localhost"
end
