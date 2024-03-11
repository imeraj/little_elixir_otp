defmodule Blitzy.Worker do
  @moduledoc false

  use Timex
  require Logger

  def start(url) do
    try do
      {timestamp, response} = Duration.measure(fn -> Req.get!(url) end)
      handle_response({Duration.to_milliseconds(timestamp), response})
    rescue
      e in RuntimeError ->
        Logger.info("worker [#{node()} - #{inspect(self())} error due to #{inspect(e)}")
        {:error, e.message}
    end
  end

  defp handle_response({msecs, %Req.Response{status: code}})
       when code >= 200 and code <= 304 do
    Logger.info("worker [#{node()} - #{inspect(self())} completed #{msecs} msecs")
    {:ok, msecs}
  end

  defp handle_response({_msecs, {:error, reason}}) do
    Logger.info("worker [#{node()} - #{inspect(self())} error due to #{inspect(reason)}")
    {:error, reason}
  end

  defp handle_response({_msecs, _}) do
    Logger.info("worker [#{node()} - #{inspect(self())} errored out")
    {:error, :unknown}
  end
end
