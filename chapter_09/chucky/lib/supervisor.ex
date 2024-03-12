defmodule Chucky.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: {:global, __MODULE__})
  end

  # callbacks
  def init(:ok) do
    children = [
      %{
        id: ChuckyServer,
        start: {Chucky.Server, :start_link, []}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
