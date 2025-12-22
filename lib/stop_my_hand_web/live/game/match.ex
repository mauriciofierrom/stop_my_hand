defmodule StopMyHandWeb.Game.Match do
  @moduledoc """
  The view where actual matches take place
  """
  use StopMyHandWeb, :live_view

  alias StopMyHand.Game
  alias StopMyHand.Game.Player
  alias StopMyHand.Game.Round
  alias StopMyHand.Game.Score
  alias StopMyHandWeb.Endpoint
  alias StopMyHand.MatchDriver

  @categories [:name, :last_name, :city, :color, :animal, :thing]
  @ordered_cats Enum.sort_by(Enum.with_index(@categories), fn {_, idx} -> idx end)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-5 items-center justify-center">
      <h1 class="text-8xl">ROUND <%= @round_number %></h1>
      <div id="counter" class="shadow-md text-6xl"></div>
      <div id="game" class={["flex flex-col gap-5 items-center justify-center"]} phx-hook="MatchHook">
        <div id="letter" class="text-8xl text-accent"></div>
        <.simple_form :let={f} for={to_form(Map.from_struct(@round))} id="round">
          <div class="flex gap-3">
            <%= for category <- @categories do %>
              <.scored_field form={f} category={category} score={get_in(@player_data, [@current_user.id, :answers, category, :result])} />
            <% end %>
          </div>
        </.simple_form>
        <.player_view players={@players}
          player_data={@player_data}
          reviewing={@reviewing}
          current_category={@current_category}
          current_user_id={@current_user.id}
          categories={@categories}
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
    |> assign(:player_data, %{})
    |> assign(:categories, @categories)
    |> assign(:reviewing, false)
    |> assign(:current_category, :name)
    |> push_event("connect_match", %{match_id: match.id})
    |> start_async(:fetch_players, fn -> Game.get_match_players(match.id) end)
    }
  end

  def handle_async(:fetch_players, {:ok, players}, socket) do
    current_user_id = socket.assigns.current_user.id
    creator_id = socket.assigns.match.creator.id

    player_ids = for player <- players, do: player.user_id
    full_player_ids = [creator_id|player_ids]

    player_handles = for player <- players, do: {player.user_id, player.user.username}
    full_player_handles =
      if current_user_id == creator_id, do: player_handles, else: [{creator_id, socket.assigns.match.creator.username}|player_handles]

    player_data = enriched_player_data(full_player_ids, full_player_handles)

    {:noreply, socket
     |> assign(:players, full_player_ids)
     |> assign(:handles, full_player_handles)
     |> assign(:player_data, player_data)
    }
  end

  def handle_event("review_answer", %{"playerid" => raw_player_id, "result" => result}, socket) do
    player_id = String.to_integer(raw_player_id)
    current_user_id = socket.assigns.current_user.id

    # Update the driver's state
    {:ok, updated_player_data} =
      MatchDriver.report_review(socket.assigns.match.id, %{
            reviewer_id: current_user_id,
            player_id: player_id,
            result: String.to_existing_atom(result)})
    enriched_updated_player_data = enrich_with_handlers(updated_player_data, socket.assigns.handles)

    {:noreply, assign(socket, :player_data, enriched_updated_player_data)}
  end

  def handle_event("enable_review", %{"category" => category}, socket) do
    updated_player_data = enrich_with_handlers(MatchDriver.get_player_data(socket.assigns.match.id), socket.assigns.handles)

    {:noreply, socket
    |> assign(:reviewing, true)
    |> assign(:player_data, updated_player_data)
    |> assign(:current_category, String.to_existing_atom(String.replace(category, "-", "_")))
    }
  end

  def handle_event("reset", _params, socket) do
    players = socket.assigns.players
    handles = socket.assigns.handles

    {:noreply, socket
     |> assign(:player_data, enriched_player_data(players, handles))
     |> assign(:round, %Round{})
     |> assign(:reviewing, false)
     |> assign(:current_category, Enum.at(@categories, 0))
    }
  end

  def handle_event("show_scores", _params, socket) do
    updated_player_data =
      enrich_with_handlers(MatchDriver.get_player_data(socket.assigns.match.id), socket.assigns.handles)

    {:noreply, assign(socket, :player_data, updated_player_data)}
  end

  defp player_view(assigns) do
    ~H"""
    <div class="flex flex-col gap-3">
      <%= for {player_id, data} <- @player_data, player_id != @current_user_id do %>
        <h2 class="text-4xl"><%= data.handle %></h2>
        <div class="flex gap-2">
          <%= for category <- @categories do %>
            <div class="flex gap-2 items-center justify-center">
              <span class="font-bold text-xl"><%= category %>:</span>
              <div class="flex flex-col items-center justify-center">
                <%= if get_in(data, [:answers, category, :result]) do %>
                  <.score result={get_in(data, [:answers, category, :result])} />
                <% end %>
                <%= if data.answers[category].value == "" do %>
                  <span>--</span>
                <% else %>
                  <div class={answer_class(get_in(data.answers, [category, :reviews, @current_user_id]))}>
                    <%= data.answers[category].value %>
                  </div>
                <% end %>
              </div>
              <%= if @reviewing && @current_category == category && data.answers[category].value != "" do %>
                <.button class={if data.answers[category].reviews[@current_user_id] == :accepted, do: "bg-accent", else: "bg-secondary"} phx-click="review_answer" phx-value-playerid={player_id} phx-value-result="accepted">
                  <.icon name="hero-check" />
                </.button>
                <.button class={if data.answers[category].reviews[@current_user_id] == :rejected, do: "bg-accent", else: "bg-secondary"} phx-click="review_answer" phx-value-playerid={player_id} phx-value-result="rejected">
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

  defp points_class(result) do
    case result do
      :accepted -> "text-green-600"
      :rejected -> "text-orange-600"
      :empty -> "text-red-600"
    end
  end

  defp enriched_player_data(player_ids, handlers) do
    Score.default_player_data(player_ids) |> enrich_with_handlers(handlers)
  end

  defp enrich_with_handlers(player_data, handlers) do
    Enum.reduce(handlers, player_data, fn {player_id, handle}, acc ->
      put_in(acc, [player_id, :handle], handle)
    end)
  end

  defp scored_field(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center">
      <%= if assigns.score do %>
        <.score result={@score} />
      <% end %>
      <div>
        <.input field={@form[@category]} label={Phoenix.Naming.humanize(@category)} data-category={Atom.to_string(@category)}/>
      </div>
    </div>
    """
  end

  defp score(assigns) do
    ~H"""
      <div class={[points_class(@result.reason), "font-bold"]}>
        <%= @result.points %>
      </div>
    """
  end
end
