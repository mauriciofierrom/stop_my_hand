defmodule StopMyHandWeb.Game.CreateMatch do
  @moduledoc """
  The modal to create a match. It allows picking the online users to invite to
  the game and then creates the match with them as players in the match.
  """
  use StopMyHandWeb, :live_component
  import Ecto.Changeset

  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.JS
  alias StopMyHand.Game.Match
  alias StopMyHand.Game

  def render(assigns) do
    ~H"""
    <div class="w-1/4 h-full">
      <.modal id="create-match-modal">
        <h1>Create Match</h1>
        <.async_result :let={friends} assign={@friends}>
          <:loading>Loading Friends...</:loading>
          <:failed :let={_failure}>There was an error fetching invites</:failed>
          <div class={[]}>
            <%= for {_n, friend} <- friends do %>
              <.friend_item_field friend={friend} target={@myself} changeset={@changeset}/>
            <% end %>
          </div>
        </.async_result>
        <.simple_form for={to_form(@changeset)} :let={f} phx-submit="save" phx-target={@myself} id="match">
          <.input type="hidden" field={f[:creator_id]} value={@current_user.id} />
          <.inputs_for :let={players_form} field={f[:players]} as={:players}>
            <.input type="hidden" field={players_form[:user_id]} />
          </.inputs_for>
          <.button disabled={Enum.empty?(@changeset.changes[:players])}>Go!</.button>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  def update(assigns, socket) do
    online_friends =
      case assigns.friends do
        %AsyncResult{ok?: true, result: result} ->
          AsyncResult.ok(Enum.filter(result, fn {_n, f} -> f.status == :online end))
        _ -> assigns.friends
      end

    {:ok, socket
     |> assign(
       current_user: assigns.current_user,
       changeset: Match.changeset(%Match{}, %{creator_id: assigns.current_user.id, players: []}),
       friends: online_friends
     )
    }
  end

  def handle_event("save", params, socket) do
    Game.create_match(socket.assigns.current_user, params)
    {:noreply, socket}
  end

  def handle_event("pick_user", %{"userid" => userid, "value" => "on"}, socket) do
    players_changes = socket.assigns.changeset.changes[:players]

    {:noreply, assign(socket,
        :changeset, put_change(
          socket.assigns.changeset,
          :players, [%{user_id: userid}|players_changes]))
    }
  end

  def handle_event("pick_user", %{"userid" => userid}, socket) do
    player_ids = Enum.map(socket.assigns.changeset.changes[:players], &(&1.changes))
    l = Enum.filter(player_ids, fn %{user_id: i} -> i != "#{userid}" end)

    {:noreply, assign(socket,
        :changeset, put_change(socket.assigns.changeset, :players,
          l))
    }
  end

  def friend_item_field(assigns) do
    ~H"""
      <span><%= assigns.friend.user.username %></span>
      <input type="checkbox"
        phx-click="pick_user"
        phx-value-userid={assigns.friend.user.id}
        phx-target={@target}
        checked={%{user_id: "#{assigns.friend.user.id}"} in Enum.map(assigns.changeset.changes[:players], &(&1.changes))}
        />
    """
  end


  def hide_modal(js \\ %JS{}) do
    js
    |> JS.hide(transition: "fade-out", to: "#create-match-modal")
  end
end
