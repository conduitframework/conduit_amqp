defmodule ConduitAMQP.Pub do
  use GenServer
  use AMQP
  require Logger

  @reconnect_after_ms 5_000

  @moduledoc """
  Worker for pooled publishers to AMQP message queue.
  """

  @doc """
  Starts the server
  """
  def start_link([broker]) do
    GenServer.start_link(__MODULE__, broker)
  end

  @doc false
  def init(broker) do
    Process.flag(:trap_exit, true)
    send(self(), :connect)
    conn_pool_name = ConduitAMQP.ConnPool.name(broker)
    {:ok, %{status: :disconnected, chan: nil, broker: broker, conn_pool_name: conn_pool_name}}
  end

  def handle_call(:chan, _from, %{status: :connected, chan: chan} = status) do
    {:reply, {:ok, chan}, status}
  end

  def handle_call(:chan, _from, %{status: :disconnected} = status) do
    {:reply, {:error, :disconnected}, status}
  end

  def handle_info(:connect, %{status: :disconnected, broker: broker} = state) do
    case ConduitAMQP.with_conn(broker, &Channel.open/1) do
      {:ok, chan} ->
        Process.monitor(chan.pid)
        Logger.info("#{inspect(self())} Channel opened for publishing")
        {:noreply, %{state | chan: chan, status: :connected}}

      {:error, reason} ->
        Logger.error("#{inspect(self())} Channel failed to open for publishing: #{inspect(reason)}")
        Process.send_after(self(), :connect, @reconnect_after_ms)
        {:noreply, %{state | chan: nil, status: :disconnected}}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.error("Channel closed, because #{inspect(reason)}")
    Process.send_after(self(), :connect, @reconnect_after_ms)
    {:noreply, %{state | status: :disconnected}}
  end

  def terminate(reason, %{chan: chan, status: :connected}) do
    Logger.info("#{inspect(self())} Closing channel, because #{inspect(reason)}")
    Channel.close(chan)

    :ok
  catch
    _, _ -> :ok
  end

  def terminate(_reason, _state), do: :ok
end
