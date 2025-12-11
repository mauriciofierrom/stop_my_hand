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

  @categories [:name, :last_name, :city, :color, :animal, :thing]
  @ordered_cats Enum.sort_by(Enum.with_index(@categories), fn {_, idx} -> idx end)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-5 items-center justify-center">
      <h1 class="text-6xl">ROUND <%= @round_number %></h1>
      <div id="counter" class="text-8xl">3</div>
      <div id="game" class={["flex flex-col gap-5 items-center justify-center", (if @reviewing, do: "", else: "hidden")]} phx-hook="MatchHook">
        <div id="letter" class="text-8xl text-accent"></div>
        <div id="round-countdown" class="shadow-md text-4xl"></div>
        <.simple_form :let={f} for={to_form(Map.from_struct(@round))} id="round">
          <div class="flex flex-column gap-3">
            <.input field={f[:name]} label="Name" data-category="name" />
            <.input field={f[:last_name]} label="Last Name" data-category="last-name" />
            <.input field={f[:city]} label="City" data-category="city" />
            <.input field={f[:color]} label="Color" data-category="color" />
            <.input field={f[:animal]} label="Animal" data-category="animal" />
            <.input field={f[:thing]} label="Thing" data-category="thing" />
          </div>
        </.simple_form>
        <.player_view players={@players}
          player_answers={@player_answers}
          reviewing={@reviewing}
          player_reviews={@player_reviews}
          current_category={@current_category}
          />
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    match = Game.get_match(params["match_id"])

    {:ok, socket
    |> assign(:match, match)
    |> assign(:round, %Round{})
    |> assign(:round_number, 1)
    |> assign(:players, [])
    |> assign(:player_answers, %{})
    |> assign(:categories, @ordered_cats)
    |> assign(:reviewing, false)
    |> assign(:player_reviews, %{})
    |> assign(:current_category, :name)
    |> push_event("connect_match", %{match_id: match.id})
    |> start_async(:fetch_players, fn -> Game.get_match_players(match.id) end)
    }
  end

  def handle_async(:fetch_players, {:ok, players}, socket) do
    filtered_players = Enum.filter(players, fn player -> player.user_id != socket.assigns.current_user.id end)
    players = Enum.map(filtered_players, fn player -> {player.user_id, player.user.username} end)
    full_players =
      if socket.assigns.current_user.id == socket.assigns.match.creator.id do
        players
      else
        [{socket.assigns.match.creator.id, socket.assigns.match.creator.username}|players]
      end

    empty_categories = Map.new(@ordered_cats, fn e -> {e, ""} end)
    player_answers = Map.new(full_players, fn {id, username} -> {id, %{handle: username, answers: empty_categories}} end)

    empty_reviews = Map.new(@categories, fn cat -> {cat, :none} end)

    # Now this looks like a job for me
    eminem = full_players
    |> Enum.filter(fn player_id -> player_id != socket.assigns.current_user.id end)
    |> Map.new(fn {player_id, _} -> {player_id, empty_reviews} end)

    {:noreply, socket
     |> assign(:players, full_players)
     |> assign(:player_answers, player_answers)
     |> assign(:player_reviews, eminem)
    }
  end

  def handle_event("accept_answer", %{"playerid" => raw_player_id}, socket) do
    player_id = String.to_integer(raw_player_id)
    # Update the driver's state
    MatchDriver.report_review(socket.assigns.match.id, %{reviewer_id: socket.assigns.current_user.id, player_id: player_id, result: :accepted})

    current_category = socket.assigns.current_category
    player_reviews = socket.assigns.player_reviews

    #TODO: What category do we have to do?
    new_player_reviews = put_in(player_reviews[player_id][current_category], :accepted)

    # TODO: update the state to mark the answer as "voted" with the result
    {:noreply, assign(socket, :player_reviews, new_player_reviews)}
  end

  def handle_event("reject_answer", %{"playerid" => raw_player_id}, socket) do
    player_id = String.to_integer(raw_player_id)
    # Update the driver's state
    MatchDriver.report_review(socket.assigns.match.id, %{reviewer_id: socket.assigns.current_user.id, player_id: player_id, result: :rejected})

    current_category = socket.assigns.current_category
    player_reviews = socket.assigns.player_reviews

    #TODO: What category do we have to do?
    new_player_reviews = put_in(player_reviews[player_id][current_category], :rejected)

    # TODO: update the state to mark the answer as "voted" with the result
    {:noreply, assign(socket, :player_reviews, new_player_reviews)}
  end

  def handle_event("enable_review", %{"category" => category, "answers" => answers}, socket) do
    converted_answers = convert_payload(answers)
    their_answers = Enum.filter(converted_answers, fn {player_id, _} -> player_id != socket.assigns.current_user.id end)

    updated_player_answers = Map.new(their_answers, fn {player_id, player_answers} ->
      {_id, handle} = Enum.find(socket.assigns.players, fn {id, _handle} -> id == player_id end)
      {player_id, %{handle: handle, answers: player_answers}}
    end)

    {:noreply, socket
    |> assign(:reviewing, true)
    |> assign(:player_answers, updated_player_answers)
    |> assign(:current_category, String.to_existing_atom(category))
    }
  end

  defp player_view(assigns) do
    ~H"""
    <div class="flex flex-col gap-3">
      <%= for {player_id, data} <- @player_answers do %>
        <h2 class="text-4xl"><%= data.handle %></h2>
        <div class="flex flex-row gap-2">
          <%= for {{cat, _}, answer} <- Enum.sort_by(data.answers, fn {{_, i}, _} -> i end) do %>
            <div class="flex flex-column gap-2 items-center justify-center">
              <span class="font-bold text-xl"><%= cat %>:</span>
              <span>
                <%= if answer == "" do %>
                  --
                <% else %>
                  <div class={answer_class(@player_reviews[player_id][cat])}>
                    <%= answer %>
                  </div>
                <% end %>
              </span>
              <%= if @reviewing && @current_category == cat && answer != "" do %>
                <.button class={if @player_reviews[player_id][cat] == :accepted, do: "bg-accent", else: "bg-secondary"} phx-click="accept_answer" phx-value-playerid={player_id} phx-value-category={cat}>
                  <.icon name="hero-check" />
                </.button>
                <.button class={if @player_reviews[player_id][cat] == :rejected, do: "bg-accent", else: "bg-secondary"} phx-click="reject_answer" phx-value-playerid={player_id} phx-value-category={cat}>
                  <.icon name="hero-x-mark" />
                </.button>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp convert_payload(answers) do
    Map.new(answers, fn {player_id_str, categories} ->
      {
        String.to_integer(player_id_str),
        Map.new(categories, fn {cat_str, value} ->
          cat_atom = String.to_existing_atom(String.replace(cat_str, "-", "_"))
          idx = Enum.find_index(@categories, &(&1 == cat_atom))
          {{cat_atom, idx}, value}
        end)
      }
    end)
  end

  defp answer_class(review) do
    case review do
      :accepted -> "text-green-600"
      :rejected -> "text-red-600"
      :none -> ""
    end
  end
end
