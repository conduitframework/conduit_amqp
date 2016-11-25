defmodule ConduitAMQP.Subscriber do
  use GenServer
  use AMQP
  import Conduit.Message
  alias Conduit.Message
  alias ConduitAMQP.Props

  def start_link(chan, source, subscriber, payload, props) do
    GenServer.start_link(__MODULE__, [chan, source, subscriber, payload, props])
  end

  def init([chan, source, subscriber, payload, props]) do
    Process.flag(:trap_exit, true)
    Process.monitor(chan.pid)
    send(self, :process)

    {:ok, %{chan: chan, source: source, subscriber: subscriber, payload: payload, props: props}}
  end

  def handle_info(:process, %{chan: chan, source: source, subscriber: subscriber, payload: payload, props: props} = state) do
    message = build_message(source, payload, props)

    case subscriber.call(message, []) do
      %Message{status: :ack} ->
        Basic.ack(chan, props.consumer_tag)
      %Message{status: :nack} ->
        Basic.reject(chan, props.consumer_tag)
    end

    {:stop, :normal, state}
  end

  def build_message(source, payload, props) do
    %Message{}
    |> put_source(source)
    |> put_body(payload)
    |> Props.put(props)
  end
end
