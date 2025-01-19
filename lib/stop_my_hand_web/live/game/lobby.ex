defmodule StopMyHandWeb.Game.Lobby do
  use StopMyHandWeb, :live_view

  alias StopMyHand.Game
  alias StopMyHandWeb.Presence
  alias StopMyHandWeb.Endpoint
  alias Phoenix.LiveView.AsyncResult

  def render(assigns) do
    ~H"""
    <h1>Waiting for players to join</h1>
    <.async_result :let={players} assign={@players}>
      <:loading>Loading invites...</:loading>
      <:failed :let={_failure}>There was an error fetching players for this match</:failed>
      <div class="flex flex-row">
        <%= for {player, status} <- players do %>
            <.player_status player={player} status={status} current_user={assigns.current_user}/>
        <% end %>
      </div>
      <.button disabled={Enum.empty?(Enum.filter(players, fn {_p, s} -> s == :online end))}>Start!</.button>
    </.async_result>
    """
  end

  def mount(params, _session, socket) do
    match_topic = "match:#{params["match_id"]}"
    current_user = socket.assigns.current_user
    players = Game.get_match_players(params["match_id"])

    if connected?(socket) do
      Presence.track(socket.transport_pid, match_topic, current_user.id, %{})
      Endpoint.subscribe("match_changes:#{params["match_id"]}")
    end

    online_users = Presence.list(match_topic)

    players_with_status = Enum.map(players, fn player ->
      status = if Enum.member?(Map.keys(online_users), "#{player.user.id}"), do: :online, else: :offline
      {player, status}
    end)

    {:ok,
     socket
     |> assign(:players, AsyncResult.ok(players_with_status))
    }
  end

  def handle_info(%{event: "join", payload: {_, {_, user_id}}}, socket) do
    %AsyncResult{result: players} = socket.assigns.players

    new_players_status = handle_presence(players, user_id, :online)

    {:noreply, assign(socket, :players, AsyncResult.ok(new_players_status))}
  end

  def handle_info(%{event: "leave", payload: {_, {_, user_id}}}, socket) do
    %AsyncResult{result: players} = socket.assigns.players

    new_players_status = handle_presence(players, user_id, :offline)

    {:noreply, assign(socket, :players, AsyncResult.ok(new_players_status))}
  end

  defp player_status(assigns) do
    ~H"""
      <div class="flex flex-column">
        <%= player_handle(assigns.player, assigns.current_user) %>
        <span class={status_message_class(assigns.status)}>
            <%= assigns.status %>
        </span>
      </div>
    """
  end

  defp status_message_class(status) do
    base = ["text-sm italic"]
    case status do
      :online -> ["text-green-500" | base]
      _ -> ["text-gray-500" | base]
    end
  end

  defp player_handle(player, current_user) do
    if player.user.username == current_user.username, do: "Me", else: player.user.username
  end

  defp handle_presence(players, user_id, event) do
    Enum.map(players, fn {player, status} ->
      if player.user.id == user_id do
        {player, event}
      else
        {player, status}
      end
    end)
  end
end
