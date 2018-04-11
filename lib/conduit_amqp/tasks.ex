defmodule ConduitAMQP.Tasks do
  @moduledoc """
  Supervises tasks
  """
  def child_spec([broker]) do
    %{
      id: name(broker),
      start: {Task.Supervisor, :start_link, [[name: name(broker)]]},
      type: :supervisor
    }
  end

  def run(broker, chan, name, source, payload, props) do
    Task.Supervisor.start_child(name(broker), ConduitAMQP.Task, :run, [broker, chan, name, source, payload, props])
  end

  def name(broker) do
    Module.concat(broker, Adapter.Tasks)
  end
end
