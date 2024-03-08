defmodule Pooly.PoolsSupervisor do
  @moduledoc false
  use DynamicSupervisor

  # API
  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_child(pool_config) do
    child_spec = %{
      id: :"#{pool_config[:name]}Supervisor",
      start: {Pooly.PoolSupervisor, :start_link, [pool_config]},
      type: :supervisor
    }

    DynamicSupervisor.start_child(Pooly.PoolsSupervisor, child_spec)
  end

  # callbacks
  def init(_) do
    opts = [strategy: :one_for_one]

    DynamicSupervisor.init(opts)
  end
end
