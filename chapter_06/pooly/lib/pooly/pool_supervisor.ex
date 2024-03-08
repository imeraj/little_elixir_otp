defmodule Pooly.PoolSupervisor do
  @moduledoc false
  use Supervisor

  # API
  def start_link(pool_config) do
    Supervisor.start_link(__MODULE__, pool_config, name: :"#{pool_config[:name]}Supervisor")
  end

  # callbacks
  def init(pool_config) do
    children = [
      %{
        id: Pooly.PoolServer,
        start: {Pooly.PoolServer, :start_link, [self(), pool_config]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
