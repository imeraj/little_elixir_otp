defmodule Pooly do
  @moduledoc false
  use Application

  alias Pooly.Worker

  @pools_config [
    [name: "Pool1", mfa: {Worker, :start_link, []}, size: 2, max_overflow: 3],
    [name: "Pool2", mfa: {Worker, :start_link, []}, size: 3, max_overflow: 1],
    [name: "Pool3", mfa: {Worker, :start_link, []}, size: 4, max_overflow: 1]
  ]

  defdelegate checkout(pool_name), to: Pooly.Server
  defdelegate checkin(pool_name, worker_pid), to: Pooly.Server
  defdelegate status(pool_name), to: Pooly.Server

  def start(_type, _arg) do
    start_pool(@pools_config)
  end

  defp start_pool(pools_config) do
    Pooly.Supervisor.start_link(pools_config)
  end
end
