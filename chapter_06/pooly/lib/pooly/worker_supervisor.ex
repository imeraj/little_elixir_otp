defmodule Pooly.WorkerSupervisor do
  @moduledoc false
  use DynamicSupervisor

  # API
  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_child({m, f, a}) do
    spec = %{id: Worker, start: {m, f, a}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  # callbacks
  def init(init_arg) do
    opts = [strategy: :one_for_one, max_restarts: 5, max_seconds: 5, extra_arguments: [init_arg]]

    DynamicSupervisor.init(opts)
  end
end
