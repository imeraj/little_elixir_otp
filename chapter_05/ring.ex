defmodule Ring do
  @moduledoc false

  def link_processes(procs) do
    link_processes(procs, [])
  end

  def link_processes([proc1, proc2 | rest], linked_processes) do
    send(proc1, {:link, proc2})
    link_processes([proc2 | rest], [proc1 | linked_processes])
  end

  def link_processes([proc| []], linked_processes) do
    first_process = List.last(linked_processes)
    send(proc, {:link, first_process})
    :ok
  end

  def create_processes(n) do
    Enum.map(1..n, fn _ -> spawn(fn -> loop() end) end)
  end

  defp loop do
    receive do
      {:link, link_to} ->
         Process.link(link_to)
         loop()

      :trap_exit ->
         Process.flag(:trap_exit, true)
         loop()

      {:EXIT, pid, reason} ->
        IO.inspect("#{inspect(self())} received {:EXIT, #{inspect(pid)} #{inspect(reason)}}" )
        loop()

      :crash -> 1/0
    end
  end
end