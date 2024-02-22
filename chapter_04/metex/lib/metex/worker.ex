defmodule Metex.Worker do
  @moduledoc false

  use GenServer

  @name __MODULE__

  ## Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, [name: @name] ++ opts)
  end

  def get_temperature(location) do
    GenServer.call(@name, {:location, location})
  end

  def get_stats do
    GenServer.call(@name, :get_stats)
  end

  def reset_stats do
    GenServer.cast(@name, :reset_stats)
  end

  def stop do
    GenServer.cast(@name, :stop)
  end

  ## Server Callbacks
  @impl GenServer
  def init(:ok) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:location, location}, _from, stats) do
    case temperature_of(location) do
      {:ok, temp} ->
        new_stats = update_stats(stats, location)
        {:reply, "#{temp}°C", new_stats}

      _ ->
        {:reply, :error, stats}
    end
  end

  def handle_call(:get_stats, _from, stats) do
    {:reply, stats, stats}
  end

  @impl GenServer
  def handle_cast(:reset_stats, _stats) do
    {:noreply, %{}}
  end

  def handle_cast(:stop, stats) do
    {:stop, :normal, stats}
  end

  @impl GenServer
  def handle_info(msg, stats) do
    IO.inspect("received #{inspect(msg)}")
    {:noreply, stats}
  end

  @impl GenServer
  def terminate(reason, stats) do
    IO.puts("Server terminated because of #{inspect(reason)}  #{inspect(stats)}")
    :ok
  end

  # Helper functions
  defp temperature_of(location) do
    url_for(location) |> Req.get!() |> parse_response()
  end

  defp url_for(location) do
    location = URI.encode(location)
    "http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{api_key()}"
  end

  defp parse_response(%Req.Response{status: 200, body: body}), do: compute_temperature(body)

  defp parse_response(_), do: :error

  defp compute_temperature(json) do
    try do
      temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok, temp}
    rescue
      _ -> :error
    end
  end

  defp update_stats(old_stats, location) do
    case Map.has_key?(old_stats, location) do
      true ->
        Map.update!(old_stats, location, &(&1 + 1))

      false ->
        Map.put_new(old_stats, location, 1)
    end
  end

  defp api_key do
    Application.fetch_env!(:metex, :api_key)
  end
end
