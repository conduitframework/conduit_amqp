defmodule ConduitAMQP.Setup do
  @moduledoc """
  Creates queues at startup and notifies pollers to start
  """
  use GenServer
  alias ConduitAMQP.Util
  alias ConduitAMQP.Topology

  defmodule State do
    @moduledoc false
    defstruct [:broker, :topology]
  end

  def child_spec([broker, _] = args) do
    %{
      id: name(broker),
      start: {__MODULE__, :start_link, args},
      restart: :transient,
      type: :worker
    }
  end

  @doc false
  def start_link(broker, topology) do
    GenServer.start_link(__MODULE__, [broker, topology], name: name(broker))
  end

  @impl true
  def init([broker, topology]) do
    Process.send(self(), :setup_topology, [])

    {:ok, %State{broker: broker, topology: topology}}
  end

  def name(broker) do
    Module.concat(broker, Adapter.Setup)
  end

  @impl true
  def handle_info(:setup_topology, %State{broker: broker, topology: topology} = state) do
    Util.retry([attempts: :infinity, jitter: 0.1], fn ->
      Topology.configure(broker, topology)
    end)

    {:stop, :normal, state}
  end
end
