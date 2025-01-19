defmodule StopMyHand.GameFixtures do
  use StopMyHand.DataCase

  import StopMyHand.AccountsFixtures

  alias StopMyHand.Game
  alias StopMyHand.Repo

  def create_match() do
    creator = user_fixture()
    player1 = user_fixture()
    player2 = user_fixture()


    {:ok, match } = Game.create_match(creator, %{
          creator_id: creator.id,
          players: [%{user_id: player1.id}, %{user_id: player2.id}]})

    match |> Repo.preload([:creator, players: [:user]])
  end
end
