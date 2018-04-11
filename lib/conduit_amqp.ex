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

  def child_spec([broker, _, _, _] = args) do
    %{
      id: name(broker),
      start: {__MODULE__, :start_link, args},
      type: :supervisor
    }
  end

  def start_link(broker, topology, subscribers, opts) do
    Supervisor.start_link(__MODULE__, [broker, topology, subscribers, opts], name: name(broker))
  end

  def init([broker, topology, subscribers, opts]) do
    Logger.info("AMQP Adapter started!")

    children = [
      {ConduitAMQP.ConnPool, [broker, opts]},
      {ConduitAMQP.PubSub, [broker, topology, subscribers, opts]},
      {ConduitAMQP.Tasks, [broker]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def name(broker) do
    Module.concat(broker, Adapter)
  end

  # TODO: Remove when conduit goes to 1.0
  # Conduit will never call this if publish/4 is defined
  def publish(message, _config, _opts) do
    {:ok, message}
  end

  def publish(broker, message, _config, opts) do
    exchange = Keyword.get(opts, :exchange)
    props = ConduitAMQP.Props.get(message)

    case get_chan(broker, 0, @pool_size) do
      {:ok, chan} ->
        Basic.publish(chan, exchange, message.destination, message.body, props)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def with_conn(broker, fun) when is_function(fun, 1) do
    with {:ok, conn} <- get_conn(broker, 0, @pool_size) do
      fun.(conn)
    end
  end

  defp get_conn(broker, retry_count, max_retry_count) do
    conn_pool = ConduitAMQP.ConnPool.name(broker)

    case :poolboy.transaction(conn_pool, &GenServer.call(&1, :conn)) do
      {:ok, conn} ->
        {:ok, conn}

      {:error, _reason} when retry_count < max_retry_count ->
        get_conn(broker, retry_count + 1, max_retry_count)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_chan(broker, retry_count, max_retry_count) do
    pool = ConduitAMQP.PubPool.name(broker)

    case :poolboy.transaction(pool, &GenServer.call(&1, :chan)) do
      {:ok, chan} ->
        {:ok, chan}

      {:error, _reason} when retry_count < max_retry_count ->
        get_chan(broker, retry_count + 1, max_retry_count)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
