defmodule StopMyHand.Scheduler.Default do
  @behaviour StopMyHand.Scheduler

  @impl true
  def send_after(pid, msg, timeout) do
    Process.send_after(pid, msg, timeout)
  end
end
