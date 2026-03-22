defmodule StopMyHandWeb.MatchChannel do
  @moduledoc """
  A Channel to drive the match mechanics
  """
  use StopMyHandWeb, :channel

  alias StopMyHand.MatchDriver

  @impl true
  def join("match:"<>raw_match_id, _payload, socket) do
    match_id = String.to_integer(raw_match_id)

    MatchDriver.add_player(match_id, socket.assigns.user)

    send(self(), :after_join)

    {:ok, assign(socket, :match_id, match_id)}
  end

  @impl true
  @doc """
  When a connection to the channel is finished we report that the player has left the match

  - To the `MatchDriver` which will decide what to do based on quorum
  - To the `WebRTC` signaling
  """
  def terminate({:shutdown, _reason}, socket) do
    MatchDriver.remove_player(socket.assigns.match_id, socket.assigns.user)

    # WebRTC
    broadcast_from!(socket, "peer_left", %{user_id: socket.assigns.user})

    {:noreply, socket}
  end

  @impl true
  @doc """
  Incoming messages for this channel:

  - `player_finished` - Player-triggered end of round (they filled all the fields).
  - `round_finished` - Timeout-triggered end of round (no player finished filling the fields until the round timeout).
  - `report_answers` - The event is triggered by players when they are requested to submit the answers that they've filled by
     the time the end-of-round conditions are met.
  - `player_activity` - This event is triggered when the player leaves a field (triggered by the blur event of an input) to
    report the activity on that category. The activity is broadcasted to all the other players so they
    can show it in their player view.
  """
  def handle_in("player_finished", _params, socket) do
    MatchDriver.finish_round(socket.assigns.match_id)
    {:noreply, socket}
  end

  def handle_in("round_finished", _params, socket) do
    MatchDriver.finish_round(socket.assigns.match_id)
    {:noreply, socket}
  end

  def handle_in("report_answers", answers, socket) do
    MatchDriver.report_player_answers(socket.assigns.match_id, socket.assigns.user, answers)
    {:noreply, socket}
  end

  def handle_in("player_activity", params, socket) do
    params_with_player_id = Map.put(params, :player_id, socket.assigns.user)

    broadcast(socket, "player_activity", params_with_player_id)

    {:noreply, socket}
  end

  @impl true
  @doc """
  This is a post-join event to be able to broadcast when the actual joined person has joined,
  which isn't possible from the `join` callback of the channel.
  """
  def handle_info(:after_join, socket) do
    # WebRTC
    broadcast_from!(socket, "peer_joined", %{user_id: socket.assigns.user})
    {:noreply, socket}
  end
end
