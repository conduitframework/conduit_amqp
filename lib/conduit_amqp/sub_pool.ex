defmodule ConduitAMQP.SubPool do
  use Supervisor

  def start_link(subscribers) do
    Supervisor.start_link(__MODULE__, [subscribers], name: __MODULE__)
  end

  def init(subscribers) do
    import Supervisor.Spec

    children = Enum.each(subscribers, fn {name, {subscriber, opts}} ->
      worker(ConduitAMQP.Sub, [subscriber, opts], id: name)
    end)

    supervise(children, strategy: :one_for_one)
  end
end
