defmodule StopMyHand.Scheduler  do
  @callback send_after(pid() | atom(), term(), non_neg_integer()) :: reference()
end
