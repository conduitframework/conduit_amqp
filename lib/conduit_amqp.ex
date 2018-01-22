defmodule ConduitAMQP do
  use Conduit.Adapter
  use Supervisor
  use AMQP
  require Logger

  @pool_size 5

  @moduledoc """
  AMQP adapter for Conduit.

    * `url` - Full connection url. Can be used instead of the individual connection options. Default is `amqp://guest:guest@localhost:5672/`.
    * `host` - Hostname of the broker (defaults to \"localhost\");
    * `port` - Port the broker is listening on (defaults to `5672`);
    * `username` - Username to connect to the broker as (defaults to \"guest\");
    * `password` - Password to connect to the broker with (defaults to \"guest\");
    * `virtual_host` - Name of a virtual host in the broker (defaults to \"/\");
    * `heartbeat` - Hearbeat interval in seconds (defaults to `0` - turned off);
    * `connection_timeout` - Connection timeout in milliseconds (defaults to `infinity`);
    * `conn_pool_size` - Number of active connections to the broker
    * `pub_pool_size` - Number of publisher channels
    * `options` - Extra RabbitMQ options

  """

  def start_link(broker, topology, subscribers, opts) do
    name = Module.concat(broker, __MODULE__)
    Supervisor.start_link(__MODULE__, [broker, topology, subscribers, opts], name: name)
  end

  def init([broker, topology, subscribers, opts]) do
    Logger.info("AMQP Adapter started!")
    import Supervisor.Spec

    conn_pool_opts = [
      name: {:local, ConduitAMQP.ConnPool},
      worker_module: ConduitAMQP.Conn,
      size: opts[:conn_pool_size] || @pool_size,
      strategy: :fifo,
      max_overflow: 0
    ]

    children = [
      :poolboy.child_spec(ConduitAMQP.ConnPool, conn_pool_opts, opts),
      supervisor(ConduitAMQP.PubSub, [broker, topology, subscribers, opts]),
      supervisor(ConduitAMQP.Subscribers, [])
    ]

    supervise(children, strategy: :one_for_one)
  end

  def publish(message, _config, opts \\ []) do
    exchange = Keyword.get(opts, :exchange)
    props = ConduitAMQP.Props.get(message)

    case get_chan(0, @pool_size) do
      {:ok, chan} ->
        Basic.publish(chan, exchange, message.destination, message.body, props)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def with_conn(fun) when is_function(fun, 1) do
    case get_conn(0, @pool_size) do
      {:ok, conn}      -> fun.(conn)
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_conn(retry_count, max_retry_count) do
    case :poolboy.transaction(ConduitAMQP.ConnPool, &GenServer.call(&1, :conn)) do
      {:ok, conn}      -> {:ok, conn}
      {:error, _reason} when retry_count < max_retry_count ->
        get_conn(retry_count + 1, max_retry_count)
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_chan(retry_count, max_retry_count) do
    case :poolboy.transaction(ConduitAMQP.PubPool, &GenServer.call(&1, :chan)) do
      {:ok, chan} ->
        {:ok, chan}
      {:error, _reason} when retry_count < max_retry_count ->
        get_chan(retry_count + 1, max_retry_count)
      {:error, reason} ->
        {:error, reason}
    end
  end
end
