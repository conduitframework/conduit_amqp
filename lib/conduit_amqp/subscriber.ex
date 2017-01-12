defmodule ConduitAMQP.Subscriber do
  use GenServer
  use AMQP
  import Conduit.Message
  alias Conduit.Message
  alias ConduitAMQP.Props

  def start_link(chan, source, broker, name, payload, props) do
    GenServer.start_link(__MODULE__, [chan, source, broker, name, payload, props])
  end

  def init([chan, source, broker, name, payload, props]) do
    Process.flag(:trap_exit, true)
    Process.monitor(chan.pid)
    send(self(), :process)

    {:ok, %{chan: chan, source: source, broker: broker, name: name, payload: payload, props: props}}
  end

  def handle_info(:process, %{chan: chan, source: source, broker: broker, name: name, payload: payload, props: props} = state) do
    message = build_message(source, payload, props)

    case broker.receives(name, message) do
      %Message{status: :ack} ->
        Basic.ack(chan, props.delivery_tag)
      %Message{status: :nack} ->
        Basic.reject(chan, props.delivery_tag)
    end

    {:stop, :normal, state}
  catch _error ->
    Basic.reject(chan, props.delivery_tag)

    {:stop, :normal, state}
  end

  def build_message(source, payload, props) do
    %Message{}
    |> put_source(source)
    |> put_body(payload)
    |> Props.put(props)
  end
end
