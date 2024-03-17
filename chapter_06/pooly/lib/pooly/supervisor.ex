defmodule Pooly.Supervisor do
  @moduledoc false
  use Supervisor

  alias Pooly.PoolsSupervisor
  alias Pooly.Server

  # API
  def start_link(pools_config) do
    Supervisor.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  # callbacks
  def init(pools_config) do
    children = [
      %{
        id: PoolsSupervisor,
        start: {PoolsSupervisor, :start_link, []},
        type: :supervisor
      },
      %{
        id: Server,
        start: {Server, :start_link, [pools_config]},
        type: :worker
      }
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
