defmodule Pooly.WorkerSupervisor do
  @moduledoc false
  use DynamicSupervisor

  # API
  def start_link(name) do
    DynamicSupervisor.start_link(__MODULE__, [], name: :"#{name}WorkerSupervisor")
  end

  def start_child(sup, {m, f, a}) do
    spec = %{id: Worker, start: {m, f, a}, restart: :temporary}
    DynamicSupervisor.start_child(sup, spec)
  end

  # callbacks
  def init(init_arg) do
    opts = [strategy: :one_for_one, max_restarts: 5, max_seconds: 5, extra_arguments: [init_arg]]

    DynamicSupervisor.init(opts)
  end
end
