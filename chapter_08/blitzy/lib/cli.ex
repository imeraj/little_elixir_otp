defmodule CLI do
  @moduledoc false
  require Logger

  # escript not working due to tzdata. So for now just ignore `main` and call `do_requests(n_requests, url)` directly from `iex`
  def main(args) do
    args
    |> parse_args()
    |> process_options()
  end

  defp parse_args(args) do
    OptionParser.parse(args, aliases: [n: :request], strict: [requests: :integer])
  end

  defp process_options(options) do
    case options do
      {[requests: n], [url], []} ->
        do_requests(n, url)

      _ ->
        do_help()
    end
  end

  defp do_help do
    IO.puts("""
    “Usage:   blitzy -n [requests] [url]    
    Options:   -n, [--requests]      # Number of requests    

    Example:  
    ./blitzy -n 100 http://www.bieberfever.com  
    """)

    System.halt(0)
  end

  # public due to :tzdata error
  def do_requests(n_requests, url) do
    Application.fetch_env!(:blitzy, :master_node)
    |> Node.start()

    Application.fetch_env!(:blitzy, :slave_nodes)
    |> Enum.each(&Node.connect(&1))

    nodes = [node() | Node.list()]

    Logger.info("Plummeting #{url} with #{n_requests} requests")

    Blitzy.run(n_requests, url, nodes)
  end
end
