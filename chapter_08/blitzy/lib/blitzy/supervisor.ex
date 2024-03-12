defmodule Blitzy.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # callbacks
  def init(:ok) do
    children = [
      {Task.Supervisor, name: Blitzy.TasksSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
