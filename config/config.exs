# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Stop lager redirecting :error_logger messages
config :lager, :error_logger_redirect, false

# Stop lager removing Logger's :error_logger handler
config :lager, :error_logger_whitelist, [Logger.ErrorHandler]

if Mix.env() == :test do
  config :conduit, ConduitAMQPTest, url: System.get_env("AMQP_URL") || "amqp://guest:guest@localhost"
end
