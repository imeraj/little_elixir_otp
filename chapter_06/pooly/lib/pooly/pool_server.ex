defmodule Pooly.PoolServer do
  @moduledoc false
  use GenServer

  defmodule State do
    @moduledoc false

    defstruct pool_sup: nil,
              worker_sup: nil,
              name: nil,
              size: nil,
              mfa: nil,
              workers: nil,
              monitors: nil,
              overflow: 0,
              max_overflow: 0,
              wait_queue: nil,
              reply_ref: nil
  end

  def start_link(pool_sup, pool_config) do
    GenServer.start_link(__MODULE__, [pool_sup, pool_config], name: name(pool_config[:name]))
  end

  def checkout(pool_name, block, timeout) do
    GenServer.call(name(pool_name), {:checkout, block}, timeout)
  end

  def checkin(pool_name, worker_pid) do
    GenServer.cast(name(pool_name), {:checkin, worker_pid})
  end

  def status(pool_name) do
    GenServer.call(name(pool_name), :status)
  end

  # callback
  @impl GenServer
  def init([pool_sup, pool_config]) when is_pid(pool_sup) do
    Process.flag(:trap_exit, true)
    wait_queue = :queue.new()
    monitors = :ets.new(:monitors, [:private])
    init(pool_config, %State{pool_sup: pool_sup, monitors: monitors, wait_queue: wait_queue})
  end

  defp init([{:name, name} | rest], state) do
    init(rest, %{state | name: name})
  end

  defp init([{:mfa, mfa} | rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  defp init([{:size, size} | rest], state) do
    init(rest, %{state | size: size})
  end

  defp init([{:max_overflow, max_overflow} | rest], state) do
    init(rest, %{state | max_overflow: max_overflow})
  end

  defp init([_ | rest], state) do
    init(rest, state)
  end

  defp init([], state) do
    send(self(), :start_worker_supervisor)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:checkout, block}, {from_pid, reply_ref}, state) do
    %{
      workers: workers,
      monitors: monitors,
      overflow: overflow,
      max_overflow: max_overflow,
      worker_sup: worker_sup,
      mfa: mfa,
      wait_queue: wait_queue
    } = state

    case workers do
      [worker | rest] ->
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}

      [] when overflow >= 0 and overflow < max_overflow ->
        ref = Process.monitor(from_pid)
        worker = new_worker(worker_sup, mfa)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | overflow: overflow + 1}}

      [] when block == true ->
        ref = Process.monitor(from_pid)
        wait_queue = :queue.in({from_pid, ref, reply_ref}, wait_queue)
        {:noreply, %{state | wait_queue: wait_queue}, :infinity}

      [] ->
        {:reply, :full, state}
    end
  end

  def handle_call(:status, _from, state) do
    %{workers: workers, monitors: monitors} = state
    {:reply, {state_name(state), length(workers), :ets.info(monitors, :size)}, state}
  end

  @impl GenServer
  def handle_cast({:checkin, worker}, state) do
    %{monitors: monitors} = state

    case :ets.lookup(monitors, worker) do
      [{^worker, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, worker)
        new_state = handle_checkin(worker, state)
        {:noreply, new_state}

      [] ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:start_worker_supervisor, state) do
    %{pool_sup: pool_sup, size: size, name: name} = state

    spec = %{
      id: name <> "WorkerSupervisor",
      start: {Pooly.WorkerSupervisor, :start_link, [name]},
      type: :supervisor,
      restart: :temporary
    }

    {:ok, worker_sup} = Supervisor.start_child(pool_sup, spec)
    Process.link(worker_sup)
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

  # Handle WorkerSupervisor EXIT
  def handle_info(
        {:EXIT, worker_sup, reason},
        %{worker_sup: worker_sup} = state
      ) do
    {:stop, reason, state}
  end

  # Handle worker EXIT
  def handle_info(
        {:EXIT, pid, _reason},
        state
      ) do
    %{monitors: monitors} = state

    case :ets.lookup(monitors, pid) do
      [{^pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = handle_worker_exit(state)
        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :ok
  end

  # private functions
  defp prepopulate(size, sup, state) do
    do_prepopulate(size, sup, state.mfa, [])
  end

  defp do_prepopulate(size, _sup, _mfa, workers) when size < 1 do
    workers
  end

  defp do_prepopulate(size, sup, mfa, workers) do
    do_prepopulate(size - 1, sup, mfa, [new_worker(sup, mfa) | workers])
  end

  defp new_worker(sup, mfa) do
    {:ok, worker} = Pooly.WorkerSupervisor.start_child(sup, mfa)
    Process.link(worker)
    worker
  end

  # private functions
  defp name(pool_name) do
    :"#{pool_name}Server"
  end

  defp handle_checkin(worker, state) do
    %{
      workers: workers,
      monitors: monitors,
      overflow: overflow,
      worker_sup: worker_sup,
      wait_queue: wait_queue
    } =
      state

    case :queue.out(wait_queue) do
      {{:value, {pid, ref, reply_ref}}, left} ->
        true = :ets.insert(monitors, {worker, ref})
        GenServer.reply({pid, reply_ref}, worker)
        %{state | wait_queue: left}

      {:empty, empty} when overflow > 0 ->
        :ok = dismiss_worker(worker_sup, worker)
        %{state | wait_queue: empty, overflow: overflow - 1}

      {:empty, empty} ->
        %{state | workers: [worker | workers], overflow: 0, wait_queue: empty}
    end
  end

  defp handle_worker_exit(state) do
    %{
      workers: workers,
      worker_sup: worker_sup,
      mfa: mfa,
      overflow: overflow,
      wait_queue: wait_queue,
      monitors: monitors
    } = state

    case :queue.out(wait_queue) do
      {{:value, {pid, ref, reply_ref}}, left} ->
        new_worker = new_worker(worker_sup, mfa)
        true = :ets.insert(monitors, {new_worker, ref})
        GenServer.reply({pid, reply_ref}, new_worker)
        %{state | wait_queue: left}

      {:empty, empty} when overflow > 0 ->
        %{state | wait_queue: empty, overflow: overflow - 1}

      {:empty, empty} ->
        new_worker = new_worker(worker_sup, mfa)
        %{state | workers: [new_worker | workers], overflow: 0, wait_queue: empty}
    end
  end

  defp dismiss_worker(worker_sup, worker) do
    Process.unlink(worker)
    DynamicSupervisor.terminate_child(worker_sup, worker)
  end

  defp state_name(%State{overflow: overflow} = state) when overflow < 1 do
    %{workers: workers, max_overflow: max_overflow} = state

    case length(workers) == [] do
      true ->
        if max_overflow < 1 do
          :full
        else
          :overflow
        end

      false ->
        :ready
    end
  end

  defp state_name(%State{overflow: max_overflow, max_overflow: max_overflow}), do: :full
  defp state_name(_state), do: :overflow
end
