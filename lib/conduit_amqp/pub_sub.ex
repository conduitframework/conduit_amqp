defmodule ConduitAMQP.PubSub do
  use Supervisor
  use AMQP

  @moduledoc """
  Supervisor for subscriber and publisher pools. Sets up queues and exchanges that are configured.
  """

  def child_spec([broker, _, _, _] = args) do
    %{
      id: name(broker),
      start: {__MODULE__, :start_link, args},
      type: :supervisor
    }
  end

  def start_link(broker, topology, subscribers, opts) do
    Supervisor.start_link(__MODULE__, [broker, topology, subscribers, opts], name: __MODULE__)
  end

  @doc false
  def init([broker, topology, subscribers, opts]) do
    case ConduitAMQP.with_conn(broker, &Channel.open/1) do
      {:ok, chan} -> configure(chan, topology)
    end

    children = [
      {ConduitAMQP.PubPool, [broker, opts]},
      {ConduitAMQP.SubPool, [broker, subscribers, opts]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def name(broker) do
    Module.concat(broker, Adapter.PubSub)
  end

  defp configure(chan, topology) do
    ConduitAMQP.Topology.configure(chan, topology)
  end
end
