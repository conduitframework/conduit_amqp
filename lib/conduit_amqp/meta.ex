defmodule ConduitAMQP.Meta do
  @moduledoc false

  @type broker :: atom
  @type status :: :incomplete | :complete
  @type exchange :: String.t()
  @type queue :: String.t()
  @type binding :: String.t()

  @spec create(broker) :: atom
  def create(broker) do
    broker
    |> meta_name()
    |> :ets.new([:set, :public, :named_table])
  end

  @spec delete(broker) :: true
  def delete(broker) do
    broker
    |> meta_name()
    |> :ets.delete()
  end

  @spec put_setup_status(broker, status) :: boolean
  def put_setup_status(broker, status) do
    insert_status(broker, :setup, status)
  end

  @spec get_setup_status(broker) :: status
  def get_setup_status(broker) do
    lookup_status(broker, :setup)
  end

  @spec put_exchange_status(broker, exchange, status) :: boolean
  def put_exchange_status(broker, exchange, status) do
    insert_status(broker, {:exchange, exchange}, status)
  end

  @spec get_exchange_status(broker, exchange) :: status
  def get_exchange_status(broker, exchange) do
    lookup_status(broker, {:exchange, exchange}, fn ->
      get_setup_status(broker)
    end)
  end

  @spec put_queue_status(broker, queue, status) :: boolean
  def put_queue_status(broker, queue, status) do
    insert_status(broker, {:queue, queue}, status)
  end

  @spec get_queue_status(broker, queue) :: status
  def get_queue_status(broker, queue) do
    lookup_status(broker, {:queue, queue}, fn ->
      get_setup_status(broker)
    end)
  end

  @spec put_binding_status(broker, binding, status) :: boolean
  def put_binding_status(broker, binding, status) do
    insert_status(broker, {:binding, binding}, status)
  end

  @spec get_binding_status(broker, binding) :: status
  def get_binding_status(broker, binding) do
    lookup_status(broker, {:binding, binding}, fn ->
      get_setup_status(broker)
    end)
  end

  defp meta_name(broker) do
    Module.concat([broker, Meta])
  end

  defp insert_status(broker, key, status) do
    broker
    |> meta_name()
    |> :ets.insert({key, status})
  end

  defp lookup_status(broker, key, fallback \\ fn -> :incomplete end) do
    broker
    |> meta_name()
    |> :ets.lookup(key)
    |> case do
      [] ->
        fallback.()

      [{_, status} | _] ->
        status
    end
  end
end
