defmodule StopMyHand.TestScenarios do
  alias StopMyHand.Accounts

  import StopMyHand.GameFixtures
  import StopMyHand.AccountsFixtures

  def run("login") do
    user = user_fixture()
    %{user_id: user.id}
  end

  def run("match_lobby") do
    match = create_two_match()
    %{match_id: match.id,
      creator: %{id: match.creator.id, username: match.creator.username},
      players: (for player <- match.players, do: %{id: player.user.id, username: player.user.username})
    }
  end
end
