defmodule Blitzy do
  @moduledoc false
  use Application

  def start(_type, _args) do
    Blitzy.Supervisor.start_link()
  end

  def run(n_workers, url) when n_workers > 0 do
    worker_fun = fn -> Blitzy.Worker.start(url) end

    1..n_workers
    |> Enum.map(fn _ -> Task.async(worker_fun) end)
    |> Enum.map(&Task.await(&1, :infinity))
    |> parse_results()
  end

  def run(n_requests, url, nodes) do
    Enum.map(1..n_requests, fn _ ->
      Task.Supervisor.async(
        {Blitzy.TasksSupervisor, Enum.random(nodes)},
        Blitzy.Worker,
        :start,
        [url]
      )
    end)
    |> Enum.map(&Task.await(&1, :infinity))
    |> parse_results()
  end

  defp parse_results(results) when length(results) > 0 do
    {successes, _Failures} =
      results
      |> Enum.split_with(fn x ->
        case x do
          {:ok, _} -> true
          _ -> false
        end
      end)

    total_workers = Enum.count(results)
    total_success = Enum.count(successes)
    total_failure = total_workers - total_success

    data = Enum.map(successes, fn {:ok, time} -> time end)
    average_time = average(data)
    longest_time = Enum.max(data)
    shortest_time = Enum.min(data)

    IO.puts("""
        Total workers    : #{total_workers}    
        Successful reqs  : #{total_success}    
        Failed reqs      : #{total_failure}    
        Average (msecs)  : #{average_time}    
        Longest (msecs)  : #{longest_time}    
        Shortest (msecs) : #{shortest_time}    
    """)
  end

  defp average(list) do
    sum = Enum.sum(list)
    n = Enum.count(list)

    if n >= 1 do
      sum / n
    else
      0
    end
  end
end
