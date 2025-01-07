defmodule StopMyHandWeb.Friendship.List do
  use StopMyHandWeb, :live_view
  alias StopMyHand.Friendship
  alias StopMyHand.Accounts
  alias Phoenix.LiveView.AsyncResult
  alias StopMyHandWeb.Dropdown
  alias StopMyHandWeb.Endpoint
  alias StopMyHandWeb.Presence
  alias StopMyHand.Cache

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
          <%= for {_n, friend} <- friends do %>
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
    |> assign(:friends, AsyncResult.ok([])) #}
    |> start_async(:fetch_friends, fn -> Friendship.get_friends(current_user.id) end)}
  end

  def handle_async(:fetch_friends, {:ok, friends}, socket) do
    current_user = socket.assigns.current_user

    {fs, ls} = Enum.reduce(friends, {[], []}, fn friend, {fs, ls} ->
      status = Presence.get_status(friend.id)
      {Enum.into(%{friend.id => %{user: friend, status: status}}, fs), [{friend.id, status}|ls]}
    end)

    Cache.load_online_friend_list(%{user_id: current_user.id, list: ls})

    Presence.track(socket.transport_pid, "online_users", current_user.id, %{})

    Presence.subscribe_friends_updates(current_user.id)

    {:noreply, assign(socket, :friends, AsyncResult.ok(fs))}
  end

  def handle_event("accept_invite", %{"inviteid" => inviteid}, socket) do
    invite = Friendship.get_invite_with_invitee(inviteid)
    accept_result = Friendship.accept_invite(invite)
    case accept_result do
      {:ok, _} ->
        current_user = socket.assigns.current_user

        %AsyncResult{result: invites} = socket.assigns.invites
        %AsyncResult{result: friends} = socket.assigns.friends

        Endpoint.broadcast("friendlist:#{invite.invitee_id}", "invite_accepted", %{invited_id: current_user.id})

        {:noreply, socket
        |> assign_async(:invites, fn -> {:ok, %{invites: Enum.filter(invites, &(&1.invitee.id != invite.invitee.id))}} end)
        |> assign_async(:friends, fn -> {:ok, %{friends: Enum.sort([invite.invitee | friends])}} end)
        |> put_flash(:info, "Invitation accepted")}
      _ -> {:noreply, put_flash(socket, :error, "Error when accepting invite")}
    end
  end

  def handle_event("remove_friend", %{"userid" => userid}, socket) do
    current_user = socket.assigns.current_user
    remove_result = Friendship.remove_friend(current_user, userid)
    case remove_result do
      {:ok, _} ->
          %AsyncResult{result: friends} = socket.assigns.friends
          {:noreply, socket
          |> assign_async(:friends, fn -> {:ok, %{friends: Enum.filter(friends, &(&1.id == userid))}} end)
          |> put_flash(:info, "Friend removed")}
      _ -> {:noreply, put_flash(socket, :error, "Error removing friend")}
    end
  end

  def handle_info(%{event: "invite_accepted", payload: %{invited_id: invited_id}}, socket) do
    invited = Accounts.get_user!(invited_id)

    %AsyncResult{result: invites} = socket.assigns.invites
    %AsyncResult{result: friends} = socket.assigns.friends

    {:noreply, socket
    |> assign_async(:invites, fn -> {:ok, %{invites: Enum.filter(invites, &(&1.invitee.id != invited_id))}} end)
    |> assign_async(:friends, fn -> {:ok, %{friends: Enum.sort([invited | friends])}} end)
    |> put_flash(:info, "Invitation accepted by: #{invited.username}")}
  end

  def handle_info(%{event: "invite_received", payload: %{invite_id: invite_id}}, socket) do
    invite = Friendship.get_invite_with_invitee(invite_id)

    %AsyncResult{result: invites} = socket.assigns.invites

    {:noreply, socket
    |> assign_async(:invites, fn -> {:ok, %{invites: Enum.sort([invite | invites])}} end)
    |> put_flash(:info, "Invitation received")}
  end

  def handle_info(%{event: "join", payload: {_, {_, user_id}}}, socket) do
    current_user = socket.assigns.current_user

    %AsyncResult{result: friends} = socket.assigns.friends

    new_friends = handle_presence(current_user, friends, user_id, :online)

    {:noreply, assign(socket, :friends, AsyncResult.ok(new_friends))}
  end

  def handle_info(%{event: "leave", payload: {_, {_, user_id}}}, socket) do
    current_user = socket.assigns.current_user

    %AsyncResult{result: friends} = socket.assigns.friends

    new_friends = handle_presence(current_user, friends, user_id, :offline)

    {:noreply, assign(socket, :friends, AsyncResult.ok(new_friends))}
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
      <div class="basis--2/3">
        <%= assigns.friend.user.username %>
        <span class={status_message_class(assigns.friend.status)}><%= assigns.friend.status %></span>
        <.live_component module={Dropdown} id={assigns.friend.user.id}>
          <:button>
            ...
          </:button>
          <.dropdown_item>
            <span class="text-red-800" id={ "remove-#{assigns.friend.user.id}"} phx-hook="ConfirmFriendRemoval" data-userid={ assigns.friend.user.id }>Delete</span>
          </.dropdown_item>
        </.live_component>
      </div>
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

  defp handle_presence(current_user, friends, user_id, event) do
    friend_ids = Enum.map(friends, fn {k, %{status: status}} ->
      new_status = if k == user_id, do: event, else: status

      {k, new_status} end)

    Cache.load_online_friend_list(%{user_id: current_user.id, list: friend_ids})

    Enum.map(friends, fn {k, %{user: friend, status: status}} ->
      if user_id == friend.id do
        {k, %{user: friend, status: event}}
      else
        {k, %{user: friend, status: status}}
      end
    end)
  end
end
