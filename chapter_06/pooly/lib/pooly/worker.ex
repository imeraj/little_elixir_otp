defmodule Pooly.Worker do
  @moduledoc false
  use GenServer

  # API
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def work_for(worker, duration) do
    GenServer.cast(worker, {:work_for, duration})
  end

  def stop(pid) when is_pid(pid) do
    GenServer.call(pid, :stop)
  end

  # callbacks
  def init(:ok) do
    {:ok, []}
  end

  def handle_cast({:work_for, duration}, state) do
    :timer.sleep(duration)
    {:stop, :normal, state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end
end
