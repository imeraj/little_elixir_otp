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

  def restart_child(supervisor, pid, child_spec) when is_pid(pid) do
    GenServer.call(supervisor, {:restart_child, pid, child_spec})
  end

  def count_children(supervisor) do
    GenServer.call(supervisor, :count_children)
  end

  def which_children(supervisor) do
    GenServer.call(supervisor, :which_children)
  end

  def terminate_child(supervisor, pid) when is_pid(pid) do
    GenServer.call(supervisor, {:terminate_child, pid})
  end

  def terminate(supervisor) do
    GenServer.call(supervisor, :terminate)
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
  def handle_call({:restart_child, old_pid, child_spec}, _from, state) do
    case Map.fetch(state, old_pid) do
      {:ok, ^child_spec} ->
        case restart_child(old_pid, child_spec) do
          {:ok, {new_pid, child_spec}} ->
            new_state =
              state
              |> Map.delete(old_pid)
              |> Map.put(new_pid, child_spec)

            {:reply, {:ok, new_pid}, new_state}

          :error ->
            {:reply, {:error, "error restarting child"}, state}
        end

      _ ->
        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call(:terminate, _from, state) do
    terminate_children(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:terminate_child, pid}, _from, state) do
    case terminate_child(pid) do
      :ok ->
        new_state = Map.delete(state, pid)
        {:reply, :ok, new_state}

      :error ->
        {:reply, {:error, "error terminating child"}, state}
    end
  end

  @impl GenServer
  def handle_call(:count_children, _from, state) do
    {:reply, map_size(state), state}
  end

  @impl GenServer
  def handle_call(:which_children, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_info({:EXIT, from, :killed}, state) do
    new_state = Map.delete(state, from)
    {:noreply, new_state}
  end

  def handle_info({:EXIT, old_pid, _reason}, state) do
    case Map.fetch(state, old_pid) do
      {:ok, child_spec} ->
        case restart_child(old_pid, child_spec) do
          {:ok, {new_pid, child_spec}} ->
            new_state =
              state
              |> Map.delete(old_pid)
              |> Map.put(new_pid, child_spec)

            {:noreply, new_state}

          :error ->
            {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
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

  defp restart_child(pid, child_spec) when is_pid(pid) do
    case terminate_child(pid) do
      :ok ->
        case start_child(child_spec) do
          {:ok, new_pid} ->
            {:ok, {new_pid, child_spec}}

          :error ->
            :error
        end

      :error ->
        :error
    end
  end

  defp terminate_children([]), do: :ok

  defp terminate_children(state) do
    Enum.map(state, fn {pid, _child_spec} -> terminate_child(pid) end)
  end

  defp terminate_child(pid) do
    Process.exit(pid, :kill)
    :ok
  end
end
