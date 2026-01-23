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
  alias StopMyHandWeb.Game.Match.PlayerActivity
  alias StopMyHand.MatchDriver

  @categories [:name, :last_name, :city, :color, :animal, :thing]
  @ordered_cats Enum.sort_by(Enum.with_index(@categories), fn {_, idx} -> idx end)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-5 items-center justify-center">
      <div id="local-player-view" phx-update="ignore" class="relative w-24 h-24 bg-gray-200 flex items-center justify-center text-gray-600 text-sm font-medium rounded-lg">
        <video autoplay class="w-24 h-24 object-cover" id="local-video" />
        <button id="local-mic" class="absolute bottom-2 left-2 p-1.5 bg-black bg-opacity-50 rounded-full hover:bg-opacity-70">
          <i class="hero-microphone w-4 h-4 text-green-500"></i>
        </button>
        <button id="local-camera" class="absolute bottom-2 right-2 p-1.5 bg-black bg-opacity-50 rounded-full hover:bg-opacity-70">
          <i class="hero-video-camera-slash w-4 h-4 text-white"></i>
        </button>
      </div>
      <h1 class="text-8xl"><%= gettext("ROUND") %> <%= @round_number %> - <%= Map.get(@score, @current_user.id, 0) %></h1>
      <div id="counter" class="shadow-md text-6xl" phx-update="ignore"></div>
      <div id="game" class={["flex flex-col gap-5 items-center justify-center"]} phx-hook="MatchHook">
        <div id="letter" class="text-8xl text-accent" phx-update="ignore"><%= Map.get(assigns, :current_letter, "") %></div>
        <.simple_form :let={f} for={to_form(Map.from_struct(@round))} id="round">
          <div class="flex gap-3">
            <%= for category <- @categories do %>
              <.scored_field form={f} category={category} score={get_in(@player_data, [@current_user.id, :answers, category, :result])} />
            <% end %>
          </div>
        </.simple_form>
        <div class="flex flex-col gap-3">
          <%= for {player_id, data} <- @player_data, player_id != @current_user.id do %>
            <div class="flex gap-3 items-center text-4xl">
              <.player_view peerId={player_id} />
              <h2><%= data.handle %></h2>
              <div class="font-bold">
                <%= Map.get(@score, player_id, 0) %>
              </div>
            </div>
            <%= unless @reviewing do %>
              <.player_activity player_activity={@player_activity} categories={@categories} player_id={player_id} />
            <% else %>
              <.player_review player_id={player_id} player_data={data} categories={@categories} current_user_id={@current_user.id} current_category={@current_category} />
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    IO.inspect("mounting for some reason")
    match = Game.get_match(params["match_id"])

    base_assigns = fn player_data ->
      %{
        categories: @categories,
        reviewing: false,
        round: %Round{},
        match: match,
        player_activity: default_player_activity(Map.keys(player_data), @categories),
      }
    end

    {game_status, final_assigns} =
      case MatchDriver.get_match_state(match.id) do
        {:normal, player_data} -> {:normal, Map.merge(base_assigns.(player_data), initial_match_state(match, player_data))}
        {:ongoing, current_match_state} -> {:ongoing, Map.merge(base_assigns.(current_match_state.player_data), current_match_state)}
      end

    {:ok, socket
     |> assign(final_assigns)
     |> assign(:mode, game_mode(game_status))
     |> push_event("connect_match", %{match_id: match.id, current_user_id: socket.assigns.current_user.id})
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

    {:noreply, assign(socket, :player_data, updated_player_data)}
  end

  def handle_event("enable_review", %{"category" => category}, socket) do
    updated_player_data = MatchDriver.get_player_data(socket.assigns.match.id)

    {:noreply, socket
    |> assign(:reviewing, true)
    |> assign(:player_data, updated_player_data)
    |> assign(:current_category, String.to_existing_atom(String.replace(category, "-", "_")))
    }
  end

  def handle_event("player_activity", params, socket) do
    player_activity = socket.assigns.player_activity

    letter = String.upcase(params["letter"])
    obfuscate = fn letter, size -> String.duplicate(letter, size) end

    updated_player_activity
      = put_in(player_activity, [params["player_id"], String.to_existing_atom(params["category"])], obfuscate.(letter, params["size"]))

    {:noreply, assign(socket, :player_activity, updated_player_activity)}
  end

  def handle_event("reset", _params, socket) do
    match_id = socket.assigns.match.id

    # The server knows what's what and we just ask, missing intention
    updated_player_data = MatchDriver.get_player_data(match_id)
    new_score = MatchDriver.get_player_scores(match_id)

    {:noreply, socket
     |> assign(:player_data, updated_player_data)
     |> assign(:round, %Round{})
     |> assign(:score, new_score)
     |> assign(:reviewing, false)
     |> assign(:player_activity, default_player_activity(Map.keys(updated_player_data), @categories))
     |> assign(:current_category, Enum.at(@categories, 0))
    }
  end

  def handle_event("show_scores", _params, socket) do
    updated_player_data = MatchDriver.get_player_data(socket.assigns.match.id)

    {:noreply, assign(socket, :player_data, updated_player_data)}
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

  defp default_player_activity(player_ids, categories) do
    for player_id <- player_ids, into: %{} do
      {player_id, (for category <- categories, into: %{}, do: {category, "---"})}
    end
  end

  defp initial_match_state(match, player_data) do
    %{
      match: match,
      round: %Round{},
      round_number: 1,
      current_category: :name,
      player_data: player_data,
      score: %{}
    }
  end

  defp game_mode(:normal), do: :active
  defp game_mode(:ongoing), do: :spectator

  defp scored_field(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center">
      <%= if assigns.score do %>
        <.score result={@score} />
      <% end %>
      <div>
        <.input field={@form[@category]} label={translate_category(@category)} data-category={Atom.to_string(@category)}/>
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

  def player_activity(assigns) do
    ~H"""
      <div class="flex gap-2">
        <%= for {category, activity} <- @player_activity[@player_id] do %>
          <div class="flex gap-2 items-center justify-center">
            <span class="font-bold text-xl"><%= translate_category(category) %>:</span>
            <div class="flex flex-col items-center justify-center">
              <%= activity %>
            </div>
          </div>
        <% end %>
      </div>
    """
  end

  defp player_review(assigns) do
    ~H"""
    <div class="flex gap-2">
      <%= for category <- @categories do %>
        <div class="flex gap-2 items-center justify-center">
          <span class="font-bold text-xl"><%= translate_category(category) %>:</span>
          <div class="flex flex-col items-center justify-center">
            <%= if get_in(@player_data, [:answers, category, :result]) do %>
              <.score result={get_in(@player_data, [:answers, category, :result])} />
            <% end %>
            <%= if @player_data.answers[category].value == "" do %>
              <span>--</span>
            <% else %>
              <div class={answer_class(get_in(@player_data.answers, [category, :reviews, @current_user_id]))}>
                <%= @player_data.answers[category].value %>
              </div>
            <% end %>
          </div>
          <%= if @current_category == category && @player_data.answers[category].value != "" do %>
            <.button class={if @player_data.answers[category].reviews[@current_user_id] == :accepted, do: "bg-accent", else: "bg-secondary"} phx-click="review_answer" phx-value-playerid={@player_id} phx-value-result="accepted">
              <.icon name="hero-check" />
            </.button>
            <.button class={if @player_data.answers[category].reviews[@current_user_id] == :rejected, do: "bg-accent", else: "bg-secondary"} phx-click="review_answer" phx-value-playerid={@player_id} phx-value-result="rejected">
              <.icon name="hero-x-mark" />
            </.button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp player_view(assigns) do
    ~H"""
      <div class="relative w-24 h-24 bg-gray-200 flex items-center justify-center text-gray-600 text-sm font-medium rounded-lg">
        <video autoplay class="w-24 h-24 object-cover" id={"peer-video-#{@peerId}"} />
      </div>
    """
  end
end
