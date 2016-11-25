defmodule ConduitAMQP.Props do
  import Conduit.Message

  def put(message, %{headers: headers} = props) do
    message
    |> put_headers(headers)
    |> put_props(Map.delete(props, :headers))
  end

  defp put_headers(message, :undefined), do: message
  defp put_headers(message, headers) do
    Enum.reduce headers || [], message, fn {key, _type, value} ->
      put_header(message, key, value)
    end
  end

  defp put_props(message, props) do
    Enum.reduce props, message, fn {key, value}, mess ->
      case value do
        :undefined -> mess
        nil -> mess
        val -> put_meta(mess, key, value)
      end
    end
  end
end
