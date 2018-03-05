defmodule ConduitAMQP.Conn do
  @moduledoc """
  Manages an AMQP connection
  """
  use Connection
  require Logger

  @reconnect_after_ms 5_000

  def start_link(opts \\ []) do
    Connection.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    {:connect, :init, %{opts: opts, conn: nil}}
  end

  def handle_call(:conn, _from, %{conn: nil} = status) do
    {:reply, {:error, :disconnected}, status}
  end

  def handle_call(:conn, _from, %{conn: conn} = status) do
    {:reply, {:ok, conn}, status}
  end

  def connect(_, state) do
    connect_opts = Keyword.get(state.opts, :url, state.opts)

    case AMQP.Connection.open(connect_opts) do
      {:ok, conn} ->
        Logger.info("#{inspect(self())} Connected via AMQP!")
        Process.monitor(conn.pid)
        {:ok, %{state | conn: conn}}

      {:error, reason} ->
        Logger.error("#{inspect(self())} Connection failed via AMQP! #{inspect(reason)}")
        {:backoff, @reconnect_after_ms, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{conn: %{pid: conn_pid}} = state)
      when pid == conn_pid do
    Logger.error("#{inspect(self())} Lost AMQP connection, because #{inspect(reason)}")
    Logger.info("#{inspect(self())} Attempting to reconnect...")
    {:connect, :reconnect, %{state | conn: nil}}
  end

  def terminate(_reason, %{conn: nil}), do: :ok

  def terminate(_reason, %{conn: conn}) do
    Logger.info("#{inspect(self())} AMQP connection terminating")

    AMQP.Connection.close(conn)
  catch
    _, _ ->
      :ok
  end
end
