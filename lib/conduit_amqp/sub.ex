defmodule ConduitAMQP.Sub do
  use GenServer
  use AMQP
  require Logger

  @reconnect_after_ms 5_000

  def start_link(conn_pool_name, name, subscriber, opts) do
    GenServer.start_link(__MODULE__, [conn_pool_name, name, subscriber, opts])
  end

  def init([conn_pool_name, name, subscriber, opts]) do
    Process.flag(:trap_exit, true)
    send(self, :connect)
    {:ok, %{
      status: :disconnected,
      chan: nil,
      conn_pool_name: conn_pool_name,
      name: name,
      subscriber: subscriber,
      opts: opts}}
  end

  def handle_call(:chan, _from, %{status: :connected, chan: chan} = status) do
    {:reply, {:ok, chan}, status}
  end
  def handle_call(:chan, _from, %{status: :disconnected} = status) do
    {:reply, {:error, :disconnected}, status}
  end

  def handle_info(:connect, %{status: :disconnected, name: name, opts: opts} = state) do
    case ConduitAMQP.with_conn(&Channel.open/1) do
      {:ok, chan} ->
        Process.monitor(chan.pid)
        Basic.qos(chan, opts)
        Basic.consume(chan, opts[:from] || Atom.to_string(name))

        {:noreply, %{state | chan: chan, status: :connected}}
      _ ->
        Process.send_after(self, :connect, @reconnect_after_ms)
        {:noreply, %{state | chan: nil, status: :disconnected}}
    end
  end

  def handle_info({:basic_deliver, payload, props}, %{chan: chan, subscriber: subscriber, name: name, opts: opts} = state) do
    source = opts[:from] || Atom.to_string(name)
    {:ok, _pid} = ConduitAMQP.Subscribers.start_subscriber(chan, source, subscriber, payload, props)

    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, _}, %{name: name, opts: opts} = state) do
    Logger.info("Subscribed to queue #{opts[:from] || name}")
    {:noreply, state}
  end

  def handle_info({:basic_cancel, _}, state), do: {:stop, :normal, state}
  def handle_info({:basic_cancel_ok, _}, state), do: {:noreply, state}

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    Process.send_after(self, :connect, @reconnect_after_ms)
    {:noreply, %{state | status: :disconnected}}
  end

  def terminate(_reason, %{chan: chan, status: :connected}) do
    Channel.close(chan)
  catch
    _, _ -> :ok
  end
  def terminate(_reason, _state), do: :ok
end
