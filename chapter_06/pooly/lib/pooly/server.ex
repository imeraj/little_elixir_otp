defmodule Pooly.Server do
  @moduledoc false
  use GenServer

  def start_link(pools_config) do
    GenServer.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def checkout(pool_name, block, timeout) do
    Pooly.PoolServer.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Pooly.PoolServer.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Pooly.PoolServer.status(pool_name)
  end

  # callbacks
  @impl GenServer
  def init(pools_config) do
    Enum.each(pools_config, fn pool_config ->
      send(self(), {:start_pool, pool_config})
    end)

    {:ok, pools_config}
  end

  @impl GenServer
  def handle_info({:start_pool, pool_config}, state) do
    {:ok, _pool_sup} = Pooly.PoolsSupervisor.start_child(pool_config)
    {:noreply, state}
  end
end
