defmodule StopMyHandWeb.Friendship.List do
  use StopMyHandWeb, :live_view
  alias StopMyHand.Friendship
  alias Phoenix.LiveView.AsyncResult

  def render(assigns) do
    ~H"""
    <.async_result :let={invites} assign={@invites}>
      <:loading>Loading invites...</:loading>
      <:failed :let={_failure}>there was an error fetching invites</:failed>
      <div class={[]}>
        <%= if !Enum.empty?(invites) do %>
          <h1>Invites</h1>
          <%= for invite <- invites do %>
            <.invite_item invite={invite}/>
          <% end %>
        <% end %>
      </div>
    </.async_result>

    <h1>Friends</h1>
    <.async_result :let={friends} assign={@friends}>
      <:loading>Loading friends...</:loading>
      <:failed :let={_failure}>there was an error fetching invites</:failed>
      <div class={[]}>
        <%= if !Enum.empty?(friends) do %>
          <%= for friend <- friends do %>
            <.friend_item friend={friend}/>
          <% end %>
        <% else %>
          No friends. <.link href={~p"/start"}>Search for friends!</.link>
        <% end %>
      </div>
    </.async_result>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    {:ok, socket
    |> assign_async(:invites, fn -> {:ok, %{invites: Friendship.get_pending_invites(current_user.id)}} end)
    |> assign_async(:friends, fn -> {:ok, %{friends: Friendship.get_friends(current_user.id)}} end)}
  end

  def handle_event("accept_invite", %{"inviteid" => inviteid}, socket) do
    invite = Friendship.get_invite_with_invitee(inviteid)
    accept_result = Friendship.accept_invite(invite)
    case accept_result do
      {:ok, _} ->
        %AsyncResult{result: invites} = socket.assigns.invites
        %AsyncResult{result: friends} = socket.assigns.friends
        {:noreply, socket
        |> assign_async(:invites, fn -> {:ok, %{invites: Enum.filter(invites, &(&1.invitee.id != invite.invitee.id))}} end)
        |> assign_async(:friends, fn -> {:ok, %{friends: Enum.sort([invite.invitee | friends])}} end)
        |> put_flash(:info, "Invitation accepted")}
      _ -> {:noreply, put_flash(socket, :error, "Error when accepting invite")}
    end
  end

  defp invite_item(assigns) do
    ~H"""
    <div
      class={[
        "flex flex-row"
    ]}>
      <div class="basis--2/3"><%= assigns.invite.invitee.username %></div>
      <button class="btn btn-blue" id={ "invite-#{assigns.invite.invitee.id}" } phx-hook="ConfirmInviteAccept" data-inviteid={ assigns.invite.id }>Accept</button>
    </div>
    """
  end

  defp friend_item(assigns) do
    ~H"""
    <div
      class={[
        "flex flex-row"
    ]}>
      <div class="basis--2/3"><%= assigns.friend.username %></div>
    </div>
    """
  end
end
