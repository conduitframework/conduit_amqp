defmodule ConduitAMQP.Subscribers do
  use Supervisor
  @moduledoc """
  Supervisor for subscribers that process messages.
  """

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [worker(ConduitAMQP.Subscriber, [], restart: :temporary)]

    supervise(children, strategy: :simple_one_for_one)
  end

  def start_subscriber(chan, source, broker, name, payload, props) do
    Supervisor.start_child(__MODULE__, [chan, source, broker, name, payload, props])
  end
end
