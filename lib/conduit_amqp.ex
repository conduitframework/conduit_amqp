defmodule ConduitAMQP do
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
  use Conduit.Adapter
  use Supervisor
  use AMQP
  require Logger
  alias ConduitAMQP.Meta
  alias ConduitAMQP.Util

  @type broker :: module
  @type chan :: AMQP.Channel.t()
  @type conn :: AMQP.Connection.t()

  @pool_size 5

  def child_spec([broker, _, _, _] = args) do
    %{
      id: name(broker),
      start: {__MODULE__, :start_link, args},
      type: :supervisor
    }
  end

  def start_link(broker, topology, subscribers, opts) do
    Meta.create(broker)
    Supervisor.start_link(__MODULE__, [broker, topology, subscribers, opts], name: name(broker))
  end

  def init([broker, topology, subscribers, opts]) do
    Logger.info("AMQP Adapter started!")

    children = [
      {ConduitAMQP.ConnPool, [broker, opts]},
      {ConduitAMQP.PubPool, [broker, opts]},
      {ConduitAMQP.SubPool, [broker, subscribers, opts]},
      {ConduitAMQP.Tasks, [broker]},
      {ConduitAMQP.Setup, [broker, topology]}
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

    {publisher_confirms, opts} =
      Keyword.pop(
        opts,
        :publisher_confirms,
        :no_confirmation
      )

    {publisher_confirms_timeout, _opts} =
      Keyword.pop(
        opts,
        :publisher_confirms_timeout,
        :infinity
      )

    select = fn chan ->
      if publisher_confirms in [:wait, :die] do
        Confirm.select(chan)
      else
        :ok
      end
    end

    wait_for_confirms = fn chan ->
      case {publisher_confirms, publisher_confirms_timeout} do
        {:no_confirmation, _} -> true
        {:wait, :infinity} -> Confirm.wait_for_confirms(chan)
        {:wait, timeout} -> Confirm.wait_for_confirms(chan, timeout)
        {:die, :infinity} -> Confirm.wait_for_confirms_or_die(chan)
        {:die, timeout} -> Confirm.wait_for_confirms_or_die(chan, timeout)
      end
    end

    with_chan(broker, fn chan ->
      with :ok <- select.(chan),
           :ok <- Basic.publish(chan, exchange, message.destination, message.body, props),
           true <- wait_for_confirms.(chan) do
        {:ok, message}
      end
    end)
  end

  @spec with_conn(broker, (conn -> term)) :: {:error, term} | {:ok, term} | term
  def with_conn(broker, fun) when is_function(fun, 1) do
    with {:ok, conn} <- get_conn(broker, @pool_size) do
      fun.(conn)
    end
  end

  @spec with_chan(broker, (chan -> term)) :: {:error, term} | {:ok, term} | term
  def with_chan(broker, fun) when is_function(fun, 1) do
    with {:ok, chan} <- get_chan(broker, @pool_size) do
      fun.(chan)
    end
  end

  @doc false
  defp get_conn(broker, retries) do
    pool = ConduitAMQP.ConnPool.name(broker)

    Util.retry([attempts: retries], fn ->
      :poolboy.transaction(pool, &GenServer.call(&1, :conn))
    end)
  end

  @doc false
  defp get_chan(broker, retries) do
    pool = ConduitAMQP.PubPool.name(broker)

    Util.retry([attempts: retries], fn ->
      :poolboy.transaction(pool, &GenServer.call(&1, :chan))
    end)
  end
end
