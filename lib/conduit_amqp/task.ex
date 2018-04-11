defmodule ConduitAMQP.Task do
  @moduledoc """
  Runs the pipeline for a message.
  """
  alias Conduit.Message
  alias ConduitAMQP.Props
  alias AMQP.Basic
  import Conduit.Message

  def run(broker, chan, name, source, payload, props) do
    Process.flag(:trap_exit, true)
    Process.monitor(chan.pid)

    message = build_message(source, payload, props)

    case broker.receives(name, message) do
      %Message{status: :ack} ->
        Basic.ack(chan, props.delivery_tag)

      %Message{status: :nack} ->
        Basic.reject(chan, props.delivery_tag)
    end
  catch
    _error ->
      Basic.reject(chan, props.delivery_tag)
  end

  defp build_message(source, payload, props) do
    %Message{}
    |> put_source(source)
    |> put_body(payload)
    |> Props.put(props)
  end
end
