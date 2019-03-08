# ConduitAMQP

An AMQP adapter for [Conduit](https://github.com/conduitframework/conduit).

## Installation

This package can be installed as:

  1. Add `conduit_amqp` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:conduit_amqp, "~> 0.6.1"}]
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

# Stop lager redirecting :error_logger messages
config :lager, :error_logger_redirect, false

# Stop lager removing Logger's :error_logger handler
config :lager, :error_logger_whitelist, [Logger.ErrorHandler]
```

For the full set of options, see [ConduitAQMP](https://hexdocs.pm/conduit_amqp/ConduitAMQP.html).

## Configuring Exchanges

You can define exchanges with the `exchange` macro in the
`configure` block of your Broker. The `exchange` macro accepts
the name of the exchange and options for the exchange.

### Options

  * `:type` - Either `:topic`, `:fanout`, `:direct`, or `:headers`. Defaults to `:topic`.
  * `:durable` - If set, keeps the Exchange between restarts of the broker. Defaults to `false`.
  * `:auto_delete` - If set, deletes the Exchange once all queues unbind from it. Defaults to `false`.
  * `:passive` - If set, returns an error if the Exchange does not already exist. Defaults to `false`.
  * `:internal` - If set, the exchange may not be used directly by publishers. Defaults to `false`.

See [exchange.declare](https://www.rabbitmq.com/amqp-0-9-1-reference.html#exchange.declare) for more details.

### Example

```elixir
defmodule MyApp.Broker do
  use Conduit.Broker, otp_app: :my_app

  configure do
    exchange "my.topic", type: :topic, durable: true
  end
end
```

## Configuring Queues

You can define queues with the `queue` macro in the
`configure` block of your Broker. The `queue` macro accepts
the name of the queue and options for the exchange.

### Options

  * `:durable` - If set, keeps the Queue between restarts of the broker. Defaults to `false`.
  * `:auto_delete` - If set, deletes the Queue once all subscribers disconnect. Defaults to `false`.
  * `:exclusive` - If set, only one subscriber can consume from the Queue. Defaults to `false`.
  * `:passive` - If set, raises an error unless the queue already exists.  Defaults to `false`.
  * `:from` - A list of routing keys to bind the queue to.
  * `:exchange` - Name of the exchange used to bind the queue to the routing keys.

See [queue.declare](https://www.rabbitmq.com/amqp-0-9-1-reference.html#queue.declare) for more details.

### Example

```elixir
defmodule MyApp.Broker do
  use Conduit.Broker, otp_app: :my_app

  configure do
    queue "my.queue", from: ["#.created.user"], exchange: "amq.topic", durable: true
  end
end
```

## Configuring a Subscriber

Inside an `incoming` block for a broker, you can define subscriptions to queues. Conduit will route messages on those
queues to your subscribers.

``` elixir
defmodule MyApp.Broker do
  incoming MyApp do
    subscribe :my_subscriber, MySubscriber, from: "my.queue"
    subscribe :my_other_subscriber, MyOtherSubscriber,
      from: "my.other.queue",
      prefetch_size: 20
  end
end
```

### Options

* `:from` - Accepts a string or function that resolves to the queue to consume from. Defaults to the name of the route if not specified.
* `:prefetch_size` - Size of prefetch buffer in octets. Defaults to `0`, which means no specific limit. This can also be configured globally by passing this same option when configuring your Broker.
* `:prefetch_count` - Number of messages to prefetch. Defaults to `0`, which means no specific limit. This can also be configured globally by passing this same option when configuring your Broker.
* `:consumer_tag` - Specifies the identifier for the consumer. The consumer tag is local to a channel, so two clients can use the same consumer tags. If this field is empty the server will generate a unique tag.
* `:no_local` - If the no-local field is set the server will not send messages to the connection that published them. Defaults to `false`.
* `:no_ack` - If this field is set the server does not expect acknowledgements for messages. That is, when a message is delivered to the client the server assumes the delivery will succeed and immediately dequeues it. Defaults to `false`.
* `:exclusive` - Request exclusive consumer access, meaning only this consumer can access the queue. Defaults to `false`.
* `:nowait` - If set, the server will not respond to the method. The client should not wait for a reply method. If the server could not complete the method it will raise a channel or connection exception. Defaults to `false`.
* `:arguments` - A set of arguments for the consume. Defaults to `[]`.

__Note: It's highly recommended to set `:prefetch_size` or `:prefetch_count` to a non-zero value to limit the memory consumed when a queue is backed up.__

See [basic.qos](https://www.rabbitmq.com/amqp-0-9-1-reference.html#basic.qos) for more details on options.

## Configuring a Publisher

Inside an `outgoing` block for a broker, you can define publications to exchanges. Conduit will deliver messages using the
options specified. You can override these options, by passing different options to your broker's `publish/3`.

``` elixir
defmodule MyApp.Broker do
  outgoing do
    publish :something,
      to: "my.routing_key",
      exchange: "amq.topic"
    publish :something_else,
      to: "my.other.routing_key",
      exchange: "amq.topic"
  end
end
```

### Options

* `:to` - The routing key for the message. If the message already has it's destination set, this option will be ignored.
* `:exchange` - The exchange to publish to. This option is required.

See [basic.publish](https://www.rabbitmq.com/amqp-0-9-1-reference.html#basic.publish) for more details.

## Architecture

![ConduitAQMP architecture](https://hexdocs.pm/conduit_amqp/assets/architecture.png)

When ConduitAMQP is used as an adapter for Conduit, it starts ConduitAMQP as a child supervisor. ConduitAMQP starts:

  1. ConduitAQMP.ConnPool - Creates and supervises a pool of AMQP connections.
  2. ConduitAMQP.PubSub - Creates and supervises ConduitAMQP.PubPool and ConduitAMQP.SubPool.
  3. ConduitAMQP.Subscribers - A supervisor for subscribers that process messages.
