
defmodule StopMyHand.Scheduler  do
  @callback send_after(pid() | atom(), term(), non_neg_integer()) :: reference()

  def send_after(pid, msg, timeout), do: Process.send_after(pid, msg, timeout)
end
