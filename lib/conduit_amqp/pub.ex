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
  def start_link(conn_pool_name) do
    GenServer.start_link(__MODULE__, [conn_pool_name])
  end

  @doc false
  def init([conn_pool_name]) do
    Process.flag(:trap_exit, true)
    send(self(), :connect)
    {:ok, %{status: :disconnected, chan: nil, conn_pool_name: conn_pool_name}}
  end

  def handle_call(:chan, _from, %{status: :connected, chan: chan} = status) do
    {:reply, {:ok, chan}, status}
  end

  def handle_call(:chan, _from, %{status: :disconnected} = status) do
    {:reply, {:error, :disconnected}, status}
  end

  def handle_info(:connect, %{status: :disconnected} = state) do
    case ConduitAMQP.with_conn(&Channel.open/1) do
      {:ok, chan} ->
        Process.monitor(chan.pid)
        Logger.info("#{inspect(self())} Channel opened for publishing")
        {:noreply, %{state | chan: chan, status: :connected}}

      _ ->
        Logger.error("#{inspect(self())} Channel failed to open for publishing")
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
