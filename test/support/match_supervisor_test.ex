defmodule StopMyHand.MatchSupervisor.Test do
  @behaviour StopMyHand.MatchSupervisor

  @impl true
  @doc """
  Test Match Supervisor fails
  """
  def start_match(_), do: {:error, "Some reason"}
end
