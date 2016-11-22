defmodule ConduitAMQP.Topology do
  use AMQP

  def configure(chan, topology) do
    topology_parts = Enum.group_by(topology, &elem(&1, 0), &Tuple.delete_at(&1, 0))

    configure_exchanges(chan, topology_parts[:exchange])
    configure_queues(chan, topology_parts[:queue])
  end

  def configure_exchanges(_, nil), do: nil
  def configure_exchanges(chan, exchanges) do
    Enum.each(exchanges, fn {exchange, opts} ->
      Exchange.declare(chan, exchange, opts[:type] || :topic, opts)
    end)
  end

  def configure_queues(_, nil), do: nil
  def configure_queues(chan, queues) do
    Enum.each(queues, fn {queue, opts} ->
      Queue.declare(chan, queue, opts)

      List.wrap(opts[:from])
      |> Enum.each(fn routing_key ->
        Queue.bind(chan, queue, opts[:exchange], Keyword.merge([routing_key: routing_key], opts))
      end)
    end)
  end
end
