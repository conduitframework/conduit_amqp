defmodule ConduitAMQPTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use AMQP

  defmodule Broker do
    @moduledoc false
    def receives(_name, message) do
      send(ConduitAMQPTest, {:broker, message})

      message
    end
  end

  defmodule OtherBroker do
    @moduledoc false
    def receives(_name, message) do
      send(ConduitAMQPTest, {:broker, message})

      message
    end
  end

  @topology [
    {:exchange, "exchange.test", []},
    {:queue, "queue.routing_key.test", from: ["#.tests"], exchange: "exchange.test"},
    {:queue, "queue.no_key.test", exchange: "exchange.test"},
    {:queue, "queue.no_bind.test", []},
    {:queue, "queue.test", from: ["#.test"], exchange: "exchange.test"}
  ]
  @subscribers %{queue_test: [from: "queue.test"]}
  setup_all do
    opts = Application.get_env(:conduit, ConduitAMQPTest)
    ConduitAMQP.start_link(Broker, @topology, @subscribers, opts)
    ConduitAMQP.start_link(OtherBroker, [], %{}, opts)

    ConduitAMQP.Util.wait_until(fn ->
      ConduitAMQP.Meta.get_setup_status(Broker) == :complete &&
        ConduitAMQP.Meta.get_setup_status(OtherBroker) == :complete
    end)

    :ok
  end

  setup do
    Process.register(self(), ConduitAMQPTest)

    :ok
  end

  def with_chan(broker, fun) do
    case ConduitAMQP.with_conn(broker, &Channel.open/1) do
      {:ok, chan} -> fun.(chan)
    end
  end

  describe "publisher confirms" do
    setup do
      import Conduit.Message

      message =
        %Conduit.Message{}
        |> put_destination("event.test")
        |> put_body("test")

      {:ok, %{message: message}}
    end

    test "wait for confirms, no timeout", %{message: message} do
      ConduitAMQP.publish(
        Broker,
        message,
        [],
        exchange: "exchange.test",
        publisher_confirms: :wait,
        publisher_confirms_timeout: :infinity
      )

      assert_receive {:broker, _received_message}
    end

    test "wait for confirms, with timeout", %{message: message} do
      ConduitAMQP.publish(
        Broker,
        message,
        [],
        exchange: "exchange.test",
        publisher_confirms: :wait,
        publisher_confirms_timeout: 5_000
      )

      assert_receive {:broker, _received_message}
    end

    test "wait for confirms or die, no timeout", %{message: message} do
      ConduitAMQP.publish(
        Broker,
        message,
        [],
        exchange: "exchange.test",
        publisher_confirms: :die,
        publisher_confirms_timeout: :infinity
      )

      assert_receive {:broker, _received_message}
    end

    test "wait for confirms or die, with timeout", %{message: message} do
      ConduitAMQP.publish(
        Broker,
        message,
        [],
        exchange: "exchange.test",
        publisher_confirms: :die,
        publisher_confirms_timeout: 5_000
      )

      assert_receive {:broker, _received_message}
    end
  end

  test "it configures the topology" do
    with_chan(Broker, fn chan ->
      assert :ok = Exchange.topic(chan, "exchange.test", passive: true)
      assert {:ok, %{queue: "queue.routing_key.test"}} = Queue.declare(chan, "queue.routing_key.test", passive: true)
      assert {:ok, %{queue: "queue.no_key.test"}} = Queue.declare(chan, "queue.no_key.test", passive: true)
      assert {:ok, %{queue: "queue.no_bind.test"}} = Queue.declare(chan, "queue.no_bind.test", passive: true)
    end)
  end

  test "a sent message can be received" do
    import Conduit.Message

    message =
      %Conduit.Message{}
      |> put_destination("event.test")
      |> put_body("test")

    ConduitAMQP.publish(Broker, message, [], exchange: "exchange.test")

    assert_receive {:broker, received_message}

    assert received_message.source == "queue.test"
    assert get_header(received_message, "routing_key") == "event.test"
    assert received_message.body == "test"
  end

  test "can run two adapters at the same time" do
    import Conduit.Message

    message =
      %Conduit.Message{}
      |> put_destination("event.test")
      |> put_body("test")

    ConduitAMQP.publish(Broker, message, [], exchange: "exchange.test")
    ConduitAMQP.publish(OtherBroker, message, [], exchange: "exchange.test")

    assert_receive {:broker, _}
    assert_receive {:broker, _}
  end

  describe "init/1" do
    test "returns the expected init setup" do
      {:ok, init_setup} = ConduitAMQP.init([Broker, @topology, @subscribers, [url: "amqp://guest:guest@localhost"]])

      assert init_setup ==
               {%{intensity: 3, period: 5, strategy: :one_for_one},
                [
                  {ConduitAMQPTest.Broker.Adapter.ConnPool,
                   {:poolboy, :start_link,
                    [
                      [
                        name: {:local, ConduitAMQPTest.Broker.Adapter.ConnPool},
                        worker_module: ConduitAMQP.Conn,
                        size: 5,
                        strategy: :fifo,
                        max_overflow: 0
                      ],
                      [url: "amqp://guest:guest@localhost"]
                    ]}, :permanent, 5000, :worker, [:poolboy]},
                  {ConduitAMQPTest.Broker.Adapter.PubPool,
                   {:poolboy, :start_link,
                    [
                      [
                        name: {:local, ConduitAMQPTest.Broker.Adapter.PubPool},
                        worker_module: ConduitAMQP.Pub,
                        size: 5,
                        max_overflow: 0
                      ],
                      [ConduitAMQPTest.Broker]
                    ]}, :permanent, 5000, :worker, [:poolboy]},
                  %{
                    id: ConduitAMQPTest.Broker.Adapter.SubPool,
                    start:
                      {ConduitAMQP.SubPool, :start_link,
                       [
                         ConduitAMQPTest.Broker,
                         %{queue_test: [from: "queue.test"]},
                         [url: "amqp://guest:guest@localhost"]
                       ]},
                    type: :supervisor
                  },
                  %{
                    id: ConduitAMQPTest.Broker.Adapter.Tasks,
                    start: {Task.Supervisor, :start_link, [[name: ConduitAMQPTest.Broker.Adapter.Tasks]]},
                    type: :supervisor
                  },
                  %{
                    id: ConduitAMQPTest.Broker.Adapter.Setup,
                    restart: :transient,
                    start:
                      {ConduitAMQP.Setup, :start_link,
                       [
                         ConduitAMQPTest.Broker,
                         [
                           {:exchange, "exchange.test", []},
                           {:queue, "queue.routing_key.test", [from: ["#.tests"], exchange: "exchange.test"]},
                           {:queue, "queue.no_key.test", [exchange: "exchange.test"]},
                           {:queue, "queue.no_bind.test", []},
                           {:queue, "queue.test", [from: ["#.test"], exchange: "exchange.test"]}
                         ]
                       ]},
                    type: :worker
                  }
                ]}
    end
  end
end
