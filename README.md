# ConduitAMQP

An AMQP adapter for [Conduit](https://github.com/conduitframework/conduit).

## Installation

This package can be installed as:

  1. Add `conduit_amqp` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:conduit_amqp, "~> 0.1.0"}]
    end
    ```

  2. Ensure `conduit_amqp` is started before your application:

    ```elixir
    def application do
      [applications: [:conduit_amqp]]
    end
    ```

## Configuring the Adapter

```elixir
# config/config.exs

config :my_app, MyApp.Broker,
  adapter: ConduitAMQP,
  url: "amqp://my_app:secret@my-rabbit-host.com"
```

For the full set of options, see `ConduitAQMP`.

## Configuring Exchanges

You can define exchanges with the `exchange` macro in the
`configure` block of your Broker. The `exchange` macro accepts
the name of the exchange and options for the exchange.

### Options

  * `:type`: Either `:topic`, `:fanout`, `:direct`, or `:headers`. Defaults to `:topic`.
  * `:durable`: If set, keeps the Exchange between restarts of the broker. Defaults to `false`.
  * `:auto_delete`: If set, deletes the Exchange once all queues unbind from it. Defaults to `false`.
  * `:passive`: If set, returns an error if the Exchange does not already exist. Defaults to `false`.
  * `:internal:` If set, the exchange may not be used directly by publishers. Defaults to `false`.


### Example

```elixir
defmodule MyApp.Broker do
  use Conduit.Broker, otp_app: :my_app

  configure do
    exchange "my.topic", type: "topic", durable: true
  end
end
```

## Configuring Queues


You can define queues with the `queue` macro in the
`configure` block of your Broker. The `queue` macro accepts
the name of the queue and options for the exchange.

### Options

  * `:durable` - If set, keeps the Queue between restarts of the broker. Defaults to `false`.
  * `:auto-delete` - If set, deletes the Queue once all subscribers disconnect. Defaults to `false`.
  * `:exclusive` - If set, only one subscriber can consume from the Queue. Defaults to `false`.
  * `:passive` - If set, raises an error unless the queue already exists.  Defaults to `false`.
  * `:from` - A list of routing keys to bind the queue to.
  * `:exchange` - Name of the exchange used to bind the queue to the routing keys.


### Example

```elixir
defmodule MyApp.Broker do
  use Conduit.Broker, otp_app: :my_app

  configure do
    queue "my.queue", from: ["#.created.user"], exchange: "amq.topic", durable: true
  end
end
```

## Publishing Messages
TODO

## Special Headers
TODO

## Architecture

![ConduitAQMP architecture](https://hexdocs.pm/conduit_amqp/assets/architecture.png)

When ConduitAMQP is used as an adapter for Conduit, it starts ConduitAMQP as a child supervisor. ConduitAMQP starts:

  1. ConduitAQMP.ConnPool - Creates and supervises a pool of AMQP connections.
  2. ConduitAMQP.PubSub - Creates and supervises ConduitAMQP.PubPool and ConduitAMQP.SubPool.
  3. ConduitAMQP.Subscribers - A supervisor for subscribers that process messages.
