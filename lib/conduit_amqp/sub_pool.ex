defmodule ConduitAMQP.SubPool do
  @moduledoc """
  Supervises all the subscriptions to queues
  """
  use Supervisor

  def start_link(conn_pool_name, broker, subscribers, opts) do
    Supervisor.start_link(__MODULE__, [conn_pool_name, broker, subscribers, opts], name: __MODULE__)
  end

  def init([conn_pool_name, broker, subscribers, adapter_opts]) do
    import Supervisor.Spec

    children =
      Enum.map(subscribers, fn {name, opts} ->
        worker(ConduitAMQP.Sub, [conn_pool_name, broker, name, opts ++ adapter_opts], id: name)
      end)

    supervise(children, strategy: :one_for_one)
  end
end
