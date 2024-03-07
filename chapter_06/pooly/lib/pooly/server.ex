defmodule Pooly.Server do
  @moduledoc false
  use GenServer

  alias Pooly.WorkerSupervisor

  defmodule State do
    defstruct sup: nil, worker_sup: nil, size: nil, mfa: nil, workers: nil, monitors: nil
  end

  def start_link(sup, pool_config) do
    GenServer.start_link(__MODULE__, [sup, pool_config], name: __MODULE__)
  end

  def checkout do
    GenServer.call(__MODULE__, :checkout)
  end

  def checkin(worker_pid) do
    GenServer.cast(__MODULE__, {:checkin, worker_pid})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  # callbacks
  @impl GenServer
  def init([sup, pool_config]) when is_pid(sup) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    init(pool_config, %State{sup: sup, monitors: monitors})
  end

  defp init([{:mfa, mfa} | rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  defp init([{:size, size} | rest], state) do
    init(rest, %{state | size: size})
  end

  defp init([_ | rest], state) do
    init(rest, state)
  end

  defp init([], state) do
    send(self(), :start_worker_supervisor)
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:checkout, {from_pid, _ref}, state) do
    %{workers: workers, monitors: monitors} = state

    case workers do
      [worker | rest] ->
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}

      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call(:status, _from, state) do
    %{workers: workers, monitors: monitors} = state
    {:reply, {length(workers), :ets.info(monitors, :size)}, state}
  end

  @impl GenServer
  def handle_cast({:checkin, worker}, state) do
    %{workers: workers, monitors: monitors} = state

    case :ets.lookup(monitors, worker) do
      [{^worker, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, worker)
        {:noreply, %{state | workers: [worker | workers]}}

      [] ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:start_worker_supervisor, state) do
    %{sup: sup, size: size} = state

    spec = %{
      id: WorkerSupervisor,
      start: {Pooly.WorkerSupervisor, :start_link, []},
      type: :supervisor,
      restart: :temporary
    }

    {:ok, worker_sup} = Supervisor.start_child(sup, spec)

    workers = prepopulate(size, worker_sup, state)

    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  # handle consumer DOWN
  def handle_info({:DOWN, ref, _, _, _}, state) do
    %{workers: workers, monitors: monitors} = state

    case :ets.match(monitors, {:"$1", ref}) do
      [[worker]] ->
        true = :ets.delete(monitors, worker)
        new_state = %{state | workers: [worker | workers]}
        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  # Handle worker EXIT
  def handle_info({:EXIT, pid, _reason}, state) do
    %{workers: workers, mfa: mfa, monitors: monitors} = state

    case :ets.lookup(monitors, pid) do
      [{^pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = %{state | workers: [new_worker(mfa) | workers]}
        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  # private functions
  defp prepopulate(size, sup, state) do
    do_prepopulate(size, sup, state.mfa, [])
  end

  defp do_prepopulate(size, _sup, _mfa, workers) when size < 1 do
    workers
  end

  defp do_prepopulate(size, sup, mfa, workers) do
    do_prepopulate(size - 1, sup, mfa, [new_worker(mfa) | workers])
  end

  defp new_worker(mfa) do
    {:ok, worker} = WorkerSupervisor.start_child(mfa)
    Process.link(worker)
    worker
  end
end
