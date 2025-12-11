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
  def join("match:"<>raw_match_id, payload, socket) do
    IO.inspect(socket.assigns.user)
    IO.inspect("channel joined")
    match_id = String.to_integer(raw_match_id)

    MatchDriver.player_joined(match_id, socket.assigns.user)

    {:ok, assign(socket, :match_id, match_id)}
  end

  # Player-triggered end of round (they filled all the fields)
  def handle_in("player_finished", params, socket) do
    MatchDriver.round_finished(socket.assigns.match_id)
    {:noreply, socket}
  end

  # Timeout-triggered en of round (no player finished filling the fields until the round timeout)
  def handle_in("round_finished", params, socket) do
    MatchDriver.round_finished(socket.assigns.match_id)
    {:noreply, socket}
  end

  def handle_in("report_answers", answers, socket) do
    IO.inspect(answers, label: "report answers")
    MatchDriver.player_answers(socket.assigns.match_id, socket.assigns.user, answers)
    {:noreply, socket}
  end
end
