defmodule ThySupervisor do
  @moduledoc false

  use GenServer

  # API
  def start_link(child_spec_list) when is_list(child_spec_list) do
    GenServer.start_link(__MODULE__, child_spec_list)
  end

  def start_child(supervisor, child_spec) do
    GenServer.call(supervisor, {:start_child, child_spec})
  end

  def terminate_child(supervisor, pid) when is_pid(pid) do
    GenServer.call(supervisor, {:terminate_child, pid})
  end

  # callbacks
  @impl GenServer
  def init(child_spec_list) do
    Process.flag(:trap_exit, true)

    state =
      child_spec_list
      |> start_children()
      |> Enum.into(Map.new())

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:start_child, child_spec}, _from, state) do
    case start_child(child_spec) do
      {:ok, pid} ->
        new_state = Map.put(state, pid, child_spec)
        {:reply, {:ok, pid}, new_state}

      :error ->
        {:reply, {:error, "error starting child"}, state}
    end
  end

  @impl GenServer
  def handle_call({:terminate_child, pid}, _from, state) do
    case terminate_child(pid) do
      :ok ->
        new_state = Map.delete(state, pid)
        {:reply, {:ok, pid}, new_state}

      :error ->
        {:reply, {:error, "error terminating child"}, state}
    end
  end

  @impl GenServer
  def handle_call({:EXIT, from, :killed}, state) do
    new_state = Map.delete(state, from)
    {:noreply, state}
  end

  # Helper functions
  defp start_children([child_spec | rest]) do
    case start_child(child_spec) do
      {:ok, pid} ->
        [{pid, child_spec} | start_children(rest)]

      :error ->
        :error
    end
  end

  defp start_children([]), do: []

  defp start_child({mod, fun, args}) do
    case apply(mod, fun, args) do
      pid when is_pid(pid) ->
        Process.link(pid)
        {:ok, pid}

      _ ->
        :error
    end
  end

  defp terminate_child(pid) do
    Process.exit(pid, :kill)
    :ok
  end
end
