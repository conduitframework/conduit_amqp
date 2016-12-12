defmodule ConduitAMQP.PubSub do
  use Supervisor
  use AMQP
  @moduledoc """
  Supervisor for subscriber and publisher pools. Sets up queues and exchanges that are configured.
  """


  def start_link(topology, subscribers, opts) do
    Supervisor.start_link(__MODULE__, [topology, subscribers, opts], name: __MODULE__)
  end

  @doc false
  def init([topology, subscribers, opts]) do
    import Supervisor.Spec

    case ConduitAMQP.with_conn(&Channel.open/1) do
      {:ok, chan} -> configure(chan, topology)
    end

    pub_pool_opts = [
      name: {:local, ConduitAMQP.PubPool},
      worker_module: ConduitAMQP.Pub,
      size: opts[:pub_pool_size] || 5,
      max_overflow: 0
    ]

    sub_pool_opts = [ConduitAMQP.ConnPool, subscribers, opts]

    children = [
      :poolboy.child_spec(ConduitAMQP.PubPool, pub_pool_opts, ConduitAMQP.ConnPool),
      supervisor(ConduitAMQP.SubPool, sub_pool_opts)
    ]

    supervise(children, strategy: :one_for_one)
  end

  defp configure(chan, topology) do
    ConduitAMQP.Topology.configure(chan, topology)
  end
end
