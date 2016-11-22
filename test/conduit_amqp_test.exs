defmodule ConduitAmqpTest do
  use ExUnit.Case
  use AMQP

  defmodule TestSubscriber do
    use Conduit.Subscriber

    def call(message, _opts) do
      send(ConduitAMQPTest, {:sub, message})
    end
  end

  @topology [{:queue, "queue.test", from: ["#.test"]}, {:exchange, "exchange.test", []}]
  @subscribers %{queue_test: {TestSubscriber, from: "queue.test"}
  setup_all do
    Process.register(self, ConduitAMQPTest)
    opts = Application.get_env(:conduit, ConduitAMQPTest)
    ConduitAMQP.start_link(@topology, @subscribers, opts)
  end

  test "it configures the topology" do
    ConduitAMQP
    assert {:ok, %{queue: "queue.test"}} = Queue
  end
end
