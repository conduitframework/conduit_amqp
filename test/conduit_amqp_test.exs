defmodule ConduitAmqpTest do
  use ExUnit.Case
  use AMQP

  defmodule Broker do
    def receives(_name, message) do
      send(ConduitAMQPTest, {:broker, message})

      message
    end
  end

  @topology [
    {:exchange, "exchange.test", []},
    {:queue, "queue.routing_key.test", from: ["#.test"], exchange: "exchange.test"},
    {:queue, "queue.no_key.test", exchange: "exchange.test"},
    {:queue, "queue.no_bind.test", []}
  ]
  @subscribers %{queue_test: [from: "queue.test"]}
  setup_all do
    opts = Application.get_env(:conduit, ConduitAMQPTest)
    ConduitAMQP.start_link(Broker, @topology, @subscribers, opts)

    :ok
  end

  setup do
    Process.register(self(), ConduitAMQPTest)

    :ok
  end

  defmacrop with_chan(fun) do
    quote do
      case ConduitAMQP.with_conn(&Channel.open/1) do
        {:ok, chan} -> unquote(fun).(chan)
      end
    end
  end

  test "it configures the topology" do
    with_chan fn chan ->
      assert :ok = Exchange.topic(chan, "exchange.test", passive: true)
      assert {:ok, %{queue: "queue.routing_key.test"}} = Queue.declare(chan, "queue.routing_key.test", passive: true)
      assert {:ok, %{queue: "queue.no_key.test"}} = Queue.declare(chan, "queue.no_key.test", passive: true)
      assert {:ok, %{queue: "queue.no_bind.test"}} = Queue.declare(chan, "queue.no_bind.test", passive: true)
    end
  end

  test "a sent message can be received" do
    import Conduit.Message
    message =
      %Conduit.Message{}
      |> put_destination("event.test")
      |> put_body("test")

    ConduitAMQP.publish(message, [], [exchange: "exchange.test"])

    assert_receive {:broker, received_message}

    assert received_message.source == "queue.test"
    assert get_header(received_message, "routing_key") == "event.test"
    assert received_message.body == "test"
  end
end
