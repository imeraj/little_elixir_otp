defmodule Pooly do
  @moduledoc false
  use Application

  @pool_config [mfa: {Pooly.Worker, :start_link, []}, size: 5]

  defdelegate checkout, to: Pooly.Server
  defdelegate checkin(worker_pid), to: Pooly.Server
  defdelegate status, to: Pooly.Server

  def start(_type, _arg) do
    start_pool(@pool_config)
  end

  defp start_pool(pool_config) do
    Pooly.Supervisor.start_link(pool_config)
  end
end
