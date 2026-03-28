defmodule StopMyHandWeb.MatchChannelTest do
  use StopMyHandWeb.ChannelCase

  alias StopMyHand.MatchDriver
  import StopMyHand.GameFixtures

  import Mox
  setup :set_mox_global

  setup do
    Mox.stub_with(StopMyHand.Scheduler.Mock, StopMyHand.Scheduler.Test)
    match = create_match()

    players = [match.creator|(for player <- match.players, do: player.user)]
    {:ok, pid}  = MatchDriver.start_link(
      %{players: players, match_id: match.id, scheduler: StopMyHand.Scheduler.Test}
    )

    {:ok, _, socket} =
      StopMyHandWeb.GameSocket
      |> socket(%{user: "1"})
      |> subscribe_and_join(StopMyHandWeb.MatchChannel, "match:#{match.id}")

    %{socket: socket, match: match}
  end

  test "player activity is broadcasted to the other players", %{socket: socket} do
    payload = %{category: "name", letter: "A", size: 5}
    push(socket, "player_activity", payload)

    assert_broadcast "player_activity", %{"category" =>  "name", "letter" => "A", "size" => 5}
  end
end
