defmodule Metex.Coordinator do
  @moduledoc false

  def loop(results, results_expected) when length(results) == results_expected do
    results
    |> Enum.sort()
    |> Enum.join(", ")
    |> IO.inspect()
  end

  def loop(results, results_expected) do
    receive do
      {:ok, result} ->
        loop([result | results], results_expected)

      _ ->
        loop(results, results_expected)
    end
  end
end
