defmodule ConduitAMQP.PubPool do
  @moduledoc """
  Supervises the pool of channels for publishing
  """

  def child_spec([broker, opts]) do
    pool_name = name(broker)

    pub_pool_opts = [
      name: {:local, pool_name},
      worker_module: ConduitAMQP.Pub,
      size: opts[:pub_pool_size] || 5,
      max_overflow: 0
    ]

    :poolboy.child_spec(pool_name, pub_pool_opts, [broker])
  end

  def name(broker) do
    Module.concat(broker, Adapter.PubPool)
  end
end
