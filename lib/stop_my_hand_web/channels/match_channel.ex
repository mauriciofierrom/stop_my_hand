defmodule StopMyHandWeb.MatchChannel do
  @moduledoc """
  A Channel to drive the match mechanics
  """
  use StopMyHandWeb, :channel

  alias StopMyHand.Game
  alias StopMyHand.MatchDriver
  alias StopMyHandWeb.Endpoint

  @match_topic "match"

  @impl true
  def join("match:"<>match_id, payload, socket) do
    IO.inspect(socket.assigns.user)
    IO.inspect("channel joined")

    MatchDriver.player_joined(String.to_integer(match_id), socket.assigns.user)

    {:ok, assign(socket, :match_id, match_id)}
  end

  def handle_in("round_finished", params, socket) do
    IO.inspect("player_finished received")
    # broadcast!(socket, "round_finished", params)

    {:noreply, socket}
  end
end
