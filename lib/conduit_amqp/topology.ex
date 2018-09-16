defmodule ConduitAMQP.Topology do
  use AMQP
  require Logger
  alias ConduitAMQP.Meta

  @moduledoc """
  Configures a topology using AMQP. Can create exchanges, queues, and bindings.
  """

  @doc """
  Configures a topology using AMQP. Can create exchanges, queues, and bindings.
  """
  @spec configure(broker :: atom, Conduit.Adapter.topology()) :: {:ok, term} | {:error, term}
  def configure(broker, topology) do
    topology_parts = Enum.group_by(topology, &elem(&1, 0), &Tuple.delete_at(&1, 0))

    ConduitAMQP.with_chan(broker, fn chan ->
      configure_exchanges(broker, chan, topology_parts[:exchange])
      configure_queues(broker, chan, topology_parts[:queue])

      Meta.put_setup_status(broker, :complete)

      :ok
    end)
  end

  defp configure_exchanges(_, _, nil), do: nil

  defp configure_exchanges(broker, chan, exchanges) do
    Enum.each(exchanges, fn {exchange, opts} ->
      Logger.info("Declaring exchange #{exchange}")

      with :ok <- Exchange.declare(chan, exchange, opts[:type] || :topic, opts) do
        Meta.put_exchange_status(broker, exchange, :complete)
      else
        {:error, reason} ->
          Logger.error("Failed declaring exchange #{exchange}: #{inspect(reason)}")
      end
    end)
  end

  defp configure_queues(_, _, nil), do: nil

  defp configure_queues(broker, chan, queues) do
    Enum.each(queues, fn {queue, opts} ->
      Logger.info("Declaring queue #{queue}")

      with {:ok, _} <- Queue.declare(chan, queue, opts) do
        Meta.put_queue_status(broker, queue, :complete)
        bind_queue(broker, chan, queue, opts[:from], opts[:exchange], opts)
      else
        {:error, reason} ->
          Logger.error("Failed declaring queue #{queue}: #{inspect(reason)}")
      end
    end)
  end

  defp bind_queue(_, _, _, nil, nil, _), do: :ok

  defp bind_queue(broker, chan, queue, nil, exchange, opts) do
    Logger.info("Binding queue #{queue} to exchange #{exchange}")

    with :ok <- Queue.bind(chan, queue, exchange, opts) do
      Meta.put_binding_status(broker, {exchange, queue}, :complete)
    else
      {:error, reason} ->
        Logger.error("Failed binding queue #{queue} to exchange #{exchange}: #{inspect(reason)}")
    end
  end

  defp bind_queue(broker, chan, queue, from, exchange, opts) do
    from
    |> List.wrap()
    |> Enum.each(fn routing_key ->
      Logger.info("Binding queue #{queue} to exchange #{exchange} using routing key #{routing_key}")

      with :ok <- Queue.bind(chan, queue, exchange, Keyword.merge([routing_key: routing_key], opts)) do
        Meta.put_binding_status(broker, {exchange, queue}, :complete)
      else
        {:error, reason} ->
          Logger.error("Failed binding queue #{queue} to exchange #{exchange}: #{inspect(reason)}")
      end
    end)

    :ok
  end
end
