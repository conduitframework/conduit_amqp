defmodule ConduitAMQP.SubPool do
  use Supervisor

  def start_link(conn_pool_name, subscribers, opts) do
    Supervisor.start_link(__MODULE__, [conn_pool_name, subscribers, opts], name: __MODULE__)
  end

  def init([conn_pool_name, subscribers, _]) do
    import Supervisor.Spec

    children = Enum.map(subscribers, fn {name, {subscriber, opts}} ->
      worker(ConduitAMQP.Sub, [conn_pool_name, name, subscriber, opts], id: name)
    end)

    supervise(children, strategy: :one_for_one)
  end
end
