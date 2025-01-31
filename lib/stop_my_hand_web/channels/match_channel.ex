defmodule StopMyHandWeb.MatchChannel do
  use StopMyHandWeb, :channel

  alias StopMyHand.Game

  @impl true
  def join("match:"<>match_id, payload, socket) do
    IO.inspect("joined")
    updated_joined = update_joined_ids(socket, socket.assigns.user)

    if Enum.all?(updated_joined, &Enum.member?(updated_joined, &1)) do
      send(self(), :all_in)
    end
    {:ok, assign(socket, :joined, updated_joined)}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (match:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_info(:all_in, socket) do
    broadcast!(socket, "start_countdown", %{at: System.system_time(:millisecond) + 3000})

    {:noreply, socket}
  end

  defp update_joined_ids(%{"player_ids" => player_ids}, player_id) do
    [player_id|player_ids]
  end

  defp update_joined_ids(_socket, player_id) do
    [player_id]
  end
end
