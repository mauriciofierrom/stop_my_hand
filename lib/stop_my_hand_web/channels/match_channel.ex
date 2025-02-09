defmodule StopMyHandWeb.MatchChannel do
  @moduledoc """
  A Channel to drive the match mechanics
  """
  use StopMyHandWeb, :channel

  alias StopMyHand.Game
  alias StopMyHand.MatchDriver

  @impl true
  def join("match:"<>match_id, payload, socket) do
    IO.inspect("joined")

    MatchDriver.player_joined(match_id, socket.assigns.user)

    if MatchDriver.all_players_in?(match_id) do
      send(self(), :all_in)
    end

    {:ok, assign(socket, :match_id, match_id)}
  end

  def handle_in("round_finished", params, socket) do
    IO.inspect("player_finished received")
    broadcast!(socket, "round_finished", params)

    {:noreply, socket}
  end

  def handle_info(:all_in, socket) do
    {:ok, letter} = MatchDriver.pick_letter(socket.assigns.match_id)

    broadcast!(socket, "start_countdown", %{
          at: System.system_time(:millisecond) + 3000,
          first_letter: letter})

    {:noreply, socket}
  end

  defp update_joined_ids(%{"player_ids" => player_ids}, player_id) do
    [player_id|player_ids]
  end

  defp update_joined_ids(_socket, player_id) do
    [player_id]
  end
end
