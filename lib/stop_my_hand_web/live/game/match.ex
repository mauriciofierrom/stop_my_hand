defmodule StopMyHandWeb.Game.Match do
  @moduledoc """
  The view where actual matches take place
  """
  use StopMyHandWeb, :live_view

  alias StopMyHand.Game
  alias StopMyHand.Game.Player
  alias StopMyHand.Game.Round
  alias StopMyHandWeb.Endpoint
  alias StopMyHand.MatchDriver

  def render(assigns) do
    ~H"""
    <h1>Stop my hand!</h1>
    <div id="counter">3</div>
    <div id="game" class="hidden">
      GAME IN PROGRESS
      <div id="letter"></div>
      <.simple_form :let={f} for={to_form(Map.from_struct(@round))} id="round">
        <.input field={f[:name]} label="Name" />
        <.input field={f[:last_name]} label="Last Name" />
        <.input field={f[:city]} label="City" />
        <.input field={f[:color]} label="Color" />
        <.input field={f[:animal]} label="Animal" />
        <.input field={f[:thing]} label="Thing" />
      </.simple_form>
    </div>
    """
  end

  def mount(params, _session, socket) do
    match_id = params["match_id"]

    {:ok, socket
    |> assign(:match_id, match_id)
    |> assign(:round, %Round{})
    |> start_async(:fetch_players, fn -> Game.get_match_players(match_id) end)
    }
  end

  def handle_async(:fetch_players, {:ok, players}, socket) do
    player_ids = Enum.map(players, fn %Player{user_id: user_id} -> user_id end)
    match_id = socket.assigns.match_id
    match = Game.get_match(match_id)

    # Start the driver for this match
    DynamicSupervisor
      .start_child(StopMyHand.DynamicSupervisor,
        {StopMyHand.MatchDriver,
         %{player_ids: [match.creator_id | player_ids], match_id: match_id}})

    {:ok, letter} = MatchDriver.pick_letter(match_id)

    {:noreply, push_event(socket, "connect_match", %{
               match_id: match_id,
               timestamp: System.system_time(:millisecond)})}
  end
end
