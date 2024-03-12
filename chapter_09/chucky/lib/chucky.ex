defmodule Chucky do
  @moduledoc false

  use Application
  require Logger

  def start(type, _args) do
    case type do
      :normal ->
        Logger.info("Application is started on #{node()}")

      {:takeover, old_node} ->
        Logger.info("#{node()} is taking over from #{old_node}")

      {:failover, old_node} ->
        Logger.info("#{old_node} is failing over to #{node()}")
    end

    Chucky.Supervisor.start_link()
  end

  def fact do
    Chucky.Server.fact()
  end
end
