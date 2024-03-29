defmodule ThyWorker do
  @moduledoc false

  def start_link do
    spawn(fn -> loop() end)
  end

  def loop() do
    receive do
      :stop ->
        :ok

      msg ->
        IO.inspect(msg)
        loop()
    end
  end
end
