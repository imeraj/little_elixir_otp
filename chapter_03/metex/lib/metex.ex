defmodule Metex do
  @moduledoc """
  Documentation for `Metex`.
  """

  def run(cities) when is_list(cities) do
    coordinator = spawn(Metex.Coordinator, :loop, [[], Enum.count(cities)])

    Enum.map(cities, fn city ->
      worker = spawn(Metex.Worker, :loop, [])
      send(worker, {coordinator, city})
    end)
  end
end
