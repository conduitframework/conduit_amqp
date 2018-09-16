defmodule ConduitAMQP.Util do
  @moduledoc """
  Provides utilities to wait for something to happen
  """

  @spec wait_until((() -> true | false)) :: :ok
  def wait_until(fun) when is_function(fun) do
    10
    |> Stream.interval()
    |> Enum.reduce_while(:wait, fn _, _ ->
      if(fun.(), do: {:halt, :ok}, else: {:cont, :wait})
    end)
  end

  @default_retry_opts %{
    delay: 10,
    backoff_factor: 2,
    jitter: 0,
    max_delay: 1_000,
    attempts: 3
  }
  @spec retry(opts :: Keyword.t(), (() -> {:error, term} | term)) :: term
  def retry(opts \\ [], fun) when is_function(fun) do
    opts = Map.merge(@default_retry_opts, Map.new(opts))

    sequence()
    |> delay(opts.delay, opts.backoff_factor)
    |> jitter(opts.jitter)
    |> max_delay(opts.max_delay)
    |> limit(opts.attempts)
    |> attempt(fun)
  end

  defp sequence do
    Stream.iterate(0, &Kernel.+(&1, 1))
  end

  defp delay(stream, delay, backoff_factor) do
    Stream.map(stream, fn
      0 -> 0
      retries -> delay * :math.pow(backoff_factor, retries)
    end)
  end

  defp jitter(stream, jitter) do
    Stream.map(stream, &round(:rand.uniform() * &1 * jitter + &1))
  end

  defp max_delay(stream, max_delay) do
    Stream.map(stream, &min(&1, max_delay))
  end

  defp limit(stream, :infinity), do: stream

  defp limit(stream, attempts) do
    Stream.take(stream, attempts)
  end

  defp attempt(stream, fun) do
    Enum.reduce_while(stream, nil, fn
      0, _ ->
        do_attempt(fun)

      delay, _ ->
        Process.sleep(delay)
        do_attempt(fun)
    end)
  end

  defp do_attempt(fun) do
    case fun.() do
      {:error, reason} ->
        {:cont, {:error, reason}}

      result ->
        {:halt, result}
    end
  catch
    :error, reason ->
      {:cont, {:error, reason}}
  end
end
