defmodule StopMyHandWeb.Game.Match do
  use StopMyHandWeb, :live_view

  alias StopMyHand.Game
  alias StopMyHandWeb.Endpoint

  def render(assigns) do
    ~H"""
    <h1>Stop my hand!</h1>
    <div id="counter">3</div>
    <div id="game" class="hidden">GAME IN PROGRESS</div>
    """
  end

  def mount(params, _session, socket) do
    match_id = params["match_id"]
    {:ok, socket
    |> assign(:match_id, match_id)
    |> start_async(:fetch_players, fn -> Game.get_match_players(match_id) end)
    }
  end

  def handle_async(:fetch_players, {:ok, players}, socket) do
    player_ids = Enum.map(players, &(&1.id))

    {:noreply, push_event(socket, "connect_match", %{
               match_id: socket.assigns.match_id,
               timestamp: System.system_time(:millisecond)})}
  end
end
