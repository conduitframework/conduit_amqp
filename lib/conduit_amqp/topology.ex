defmodule ConduitAMQP.Topology do
  use AMQP
  require Logger
  @moduledoc """
  Configures a topology using AMQP. Can create exchanges, queues, and bindings.
  """

  @doc """
  Configures a topology using AMQP. Can create exchanges, queues, and bindings.
  """
  @spec configure(%AMQP.Channel{}, Conduit.Adapter.topology) :: :ok
  def configure(chan, topology) do
    topology_parts = Enum.group_by(topology, &elem(&1, 0), &Tuple.delete_at(&1, 0))

    configure_exchanges(chan, topology_parts[:exchange])
    configure_queues(chan, topology_parts[:queue])

    :ok
  end

  defp configure_exchanges(_, nil), do: nil
  defp configure_exchanges(chan, exchanges) do
    Enum.each(exchanges, fn {exchange, opts} ->
      Logger.info("Declaring exchange #{exchange}")
      Exchange.declare(chan, exchange, opts[:type] || :topic, opts)
    end)
  end

  defp configure_queues(_, nil), do: nil
  defp configure_queues(chan, queues) do
    Enum.each(queues, fn {queue, opts} ->
      Logger.info("Declaring queue #{queue}")
      Queue.declare(chan, queue, opts)

      case opts[:from] do
        nil ->
          Logger.info("Binding queue #{queue} to exchange #{opts[:exchange]}")
          Queue.bind(chan, queue, opts[:exchange], opts)
        from ->
          List.wrap(from)
          |> Enum.each(fn routing_key ->
            Logger.info("Binding queue #{queue} to exchange #{opts[:exchange]} using routing key #{routing_key}")
            Queue.bind(chan, queue, opts[:exchange], Keyword.merge([routing_key: routing_key], opts))
          end)
      end
    end)
  end
end
