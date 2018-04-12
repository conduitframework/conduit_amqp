defmodule ConduitAMQP.ConnPool do
  @moduledoc """
  Supervises the pool of connections to message queue
  """
  @pool_size 5

  def child_spec([broker, opts]) do
    pool_name = name(broker)

    conn_pool_opts = [
      name: {:local, pool_name},
      worker_module: ConduitAMQP.Conn,
      size: opts[:conn_pool_size] || @pool_size,
      strategy: :fifo,
      max_overflow: 0
    ]

    :poolboy.child_spec(pool_name, conn_pool_opts, opts)
  end

  def name(broker) do
    Module.concat(broker, Adapter.ConnPool)
  end
end
