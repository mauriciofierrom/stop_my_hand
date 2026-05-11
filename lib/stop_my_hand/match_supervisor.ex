defmodule StopMyHand.MatchSupervisor do
  @callback start_match(map()) :: {:ok, pid()} | {:error, term()}

  def start_match(args) do
    DynamicSupervisor
      .start_child(StopMyHand.DynamicSupervisor,
        {StopMyHand.MatchDriver,
         args})
  end
end
