defmodule Metex.Worker do
  @moduledoc false

  def loop do
    receive do
      {sender, location} ->
        send(sender, {:ok, temperature_of(location)})
      _ ->
        :ignored
    end
    loop()
  end

  def temperature_of(location) do
    result = url_for(location) |> Req.get!() |> parse_response()

    case result do
      {:ok, temp} ->
        "#{location}: #{temp}°C"

      :error ->
        "#{location} not found"
    end
  end

  def url_for(location) do
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

  defp api_key do
    Application.fetch_env!(:metex, :api_key)
  end
end
