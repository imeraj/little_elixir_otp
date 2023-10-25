defmodule Metex.Coordinator do
  @moduledoc false

  def loop(results \\ [], results_expected) do
    receive do
      {:ok, result} ->
        new_results = [result | results]

        if results_expected == Enum.count(new_results) do
          send(self(), :exit)
        end

        loop(new_results, results_expected)

      :exit ->
        results
        |> Enum.sort()
        |> Enum.join(", ")
        |> IO.inspect()

      _ ->
        loop(results, results_expected)
    end
  end
end
