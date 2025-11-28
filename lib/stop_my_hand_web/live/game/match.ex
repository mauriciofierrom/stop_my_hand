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
    <div class="flex flex-col gap-5 items-center justify-center">
      <h1 class="text-6xl">ROUND 1</h1>
      <div id="counter" class="text-8xl">3</div>
      <div id="game" class="hidden flex flex-col gap-5 items-center justify-center">
        <div id="letter" class="text-8xl text-accent"></div>
        <div id="round-countdown" class="shadow-md text-4xl"></div>
        <.simple_form :let={f} for={to_form(Map.from_struct(@round))} id="round">
          <div class="flex flex-column gap-3">
            <.input field={f[:name]} label="Name" />
            <.input field={f[:last_name]} label="Last Name" />
            <.input field={f[:city]} label="City" />
            <.input field={f[:color]} label="Color" />
            <.input field={f[:animal]} label="Animal" />
            <.input field={f[:thing]} label="Thing" />
          </div>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    match_id = params["match_id"]

    {:ok, socket
    |> assign(:match_id, match_id)
    |> assign(:round, %Round{})
    |> push_event("connect_match", %{match_id: match_id})
    |> start_async(:fetch_players, fn -> Game.get_match_players(match_id) end)
    }
  end

  def handle_async(:fetch_players, {:ok, players}, socket) do
    player_ids = Enum.map(players, fn %Player{user_id: user_id} -> user_id end)
    match_id = socket.assigns.match_id
    match = Game.get_match(match_id)

    {:noreply, socket}
  end
end
