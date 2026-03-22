defmodule StopMyHand.Scheduler.Test do
  @behaviour StopMyHand.Scheduler

  @impl true
  @doc """
  We no-op the timeouts which means we need to explicitly use `send`
  in tests to trigger them.
  """
  def send_after(pid, msg, _timeout), do: :ok
end
