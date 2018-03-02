defmodule ConduitAMQP.Props do
  import Conduit.Message

  def put(message, props) do
    props = nilify_undefined(props)

    message
    |> put_message_headers(props.headers)
    |> put_user_id(get_header(message, "user_id"))
    |> delete_header("user_id")
    |> put_correlation_id(props.correlation_id)
    |> put_message_id(props.message_id)
    |> put_content_type(props.content_type)
    |> put_content_encoding(props.content_encoding)
    |> put_created_by(props.app_id)
    |> put_created_at(props.timestamp || get_header(message, "created_at"))
    |> delete_header("created_at")
    |> put_header("consumer_tag", props.consumer_tag)
    |> put_header("delivery_tag", props.delivery_tag)
    |> put_header("redelivered", props.redelivered)
    |> put_header("exchange", props.exchange)
    |> put_header("routing_key", props.routing_key)
    |> put_header("exchange", props.exchange)
    |> put_header("persistent", props.persistent)
    |> put_header("priority", props.priority)
    |> put_header("reply_to", props.reply_to)
    |> put_header("expiration", props.expiration)
    |> put_header("type", props.type)
    |> put_header("cluster_id", props.cluster_id)
  end

  def get(message) do
    []
    |> put_present(:content_type, message.content_type)
    |> put_present(:content_encoding, message.content_encoding)
    |> put_present(:delivery_mode, get_header(message, "delivery_mode"))
    |> put_present(:priority, get_header(message, "priority"))
    |> put_present(:correlation_id, message.correlation_id)
    |> put_present(:reply_to, get_header(message, "reply_to"))
    |> put_present(:expiration, get_header(message, "expiration"))
    |> put_present(:message_id, message.message_id)
    |> put_number(:timestamp, message.created_at)
    |> put_present(:type, get_header(message, "type"))
    |> put_present(:user_id, get_header(message, "user_id"))
    |> put_present(:app_id, message.created_by)
    |> put_present(:cluster_id, get_header(message, "cluster_id"))
    |> put_present(:mandatory, get_header(message, "mandatory"))
    |> put_present(:immediate, get_header(message, "immediate"))
    |> put_present(:headers, get_prop_headers(message))
  end

  defp put_message_headers(message, nil), do: message

  defp put_message_headers(message, headers) do
    Enum.reduce(headers, message, fn {key, _type, value}, mess ->
      put_header(mess, key, value)
    end)
  end

  defp nilify_undefined(props) do
    props
    |> Enum.map(fn
      {key, :undefined} -> {key, nil}
      {key, value} -> {key, value}
    end)
    |> Enum.into(%{})
  end

  @passed_as_props [
    "delivery_mode",
    "priority",
    "reply_to",
    "expiration",
    "type",
    "user_id",
    "cluster_id",
    "mandatory",
    "immediate"
  ]
  defp get_prop_headers(message) do
    Map.drop(message.headers, @passed_as_props)
    |> Enum.reduce([], fn {key, value}, list ->
      put_present(list, key, value)
    end)
    |> put_present("user_id", message.user_id)
    |> put_string("created_at", message.created_at)
  end

  defp put_present(list, _, nil), do: list
  defp put_present(list, key, value), do: [{key, value} | list]

  defp put_number(list, key, value) when is_integer(value), do: [{key, value} | list]
  defp put_number(list, _, _), do: list

  defp put_string(list, key, value) when is_binary(value), do: [{key, value} | list]
  defp put_string(list, _, _), do: list
end
