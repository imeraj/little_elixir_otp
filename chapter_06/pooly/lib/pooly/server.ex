defmodule Pooly.Server do
  @moduledoc false
  use GenServer

  alias Pooly.WorkerSupervisor

  defmodule State do
    defstruct sup: nil, worker_sup: nil, size: nil, mfa: nil, workers: nil
  end

  def start_link(sup, pool_config) do
    GenServer.start_link(__MODULE__, [sup, pool_config], name: __MODULE__)
  end

  # callbacks
  def init([sup, pool_config]) when is_pid(sup) do
    init(pool_config, %State{sup: sup})
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
    worker
  end
end
