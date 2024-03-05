defmodule Pooly.Supervisor do
  @moduledoc false
  use Supervisor

  alias Pooly.Server

  # API
  def start_link(pool_config) do
    Supervisor.start_link(__MODULE__, pool_config, name: __MODULE__)
  end

  # callbacks
  def init(pool_config) do
    children = [
      %{
        id: Server,
        start: {Server, :start_link, [self(), pool_config]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
