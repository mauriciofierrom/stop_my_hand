defmodule StopMyHandWeb.Main do
  use StopMyHandWeb, :live_view

  alias StopMyHand.Friendship
  alias StopMyHand.Accounts
  alias Phoenix.LiveView.AsyncResult
  alias StopMyHandWeb.Friendship.List
  alias StopMyHandWeb.Game.CreateMatch
  alias StopMyHandWeb.Endpoint
  alias StopMyHandWeb.Presence
  alias StopMyHand.Cache

  @notification "notification"

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-[4fr_1fr]">
      <div class="flex flex-col items-start gap-4">
        <h1 class="text-8xl mb-20">STOP MY HAND</h1>
        <button class="btn btn-blue text-5xl" id="create-match-btn" phx-click={show_modal("create-match-modal")}>Start Match!</button>
        <.live_component module={CreateMatch} id="create_match" friends={@friends} current_user={assigns.current_user} />
        <.game_invite game_id={@game_invite.game_id} invitee_handle={@game_invite.invitee_handle} show={@game_invite.show} />
      </div>
      <div>
        <List.friend_list current_user={assigns.current_user} friends={@friends} invites={@invites}/>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    # Subscribe to the current user's notification channel
    # TODO: Move to the handle_param stuff
    Endpoint.subscribe("#{@notification}:#{current_user.id}")

    {:ok, socket
    |> assign(:game_invite, %{game_id: nil, invitee_handle: "", show: false})
    |> assign_async(:invites, fn -> {:ok, %{invites: Friendship.get_pending_invites(current_user.id)}} end)
    |> assign(:friends, AsyncResult.ok([]))
    |> start_async(:fetch_friends, fn -> Friendship.get_friends(current_user.id) end)
    |> assign(:show_create_match_modal, false)}
  end

  def handle_async(:fetch_friends, {:ok, friends}, socket) do
    current_user = socket.assigns.current_user

    {fs, ls} = Enum.reduce(friends, {[], []}, fn friend, {fs, ls} ->
      status = Presence.get_status(friend.id)
      {[{friend.id, %{user: friend, status: status}}|fs], [{friend.id, status}|ls]}
    end)

    Cache.load_online_friend_list(%{user_id: current_user.id, list: ls})

    Presence.track(socket.transport_pid, "online_users", current_user.id, %{})

    Presence.subscribe_friends_updates(current_user.id)

    {:noreply, assign(socket, :friends, AsyncResult.ok(fs))}
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

  def handle_info(%{event: "game_invite", payload: %{game_id: game_id, invitee_handle: handle}}, socket) do
    {:noreply, assign(socket, :game_invite, %{game_id: game_id, invitee_handle: handle, show: true})}
  end

  def create_match(js \\ %JS{}) do
    js
    |> JS.show(to: "#create-match-modal")
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

  def handle_event("accept_invite", %{"inviteid" => inviteid}, socket) do
    IO.inspect("we're in accept invite")
    invite = Friendship.get_invite_with_invitee(inviteid)
    accept_result = Friendship.accept_invite(invite)
    case accept_result do
      {:ok, _} ->
        current_user = socket.assigns.current_user

        %AsyncResult{result: invites} = socket.assigns.invites
        %AsyncResult{result: friends} = socket.assigns.friends

        Endpoint.broadcast("friends:#{invite.invitee_id}", "invite_accepted", %{invited_id: current_user.id})

        {:noreply, socket
        |> assign_async(:invites, fn -> {:ok, %{invites: Enum.filter(invites, &(&1.invitee.id != invite.invitee.id))}} end)
        |> assign_async(:friends, fn -> {:ok, %{friends: Enum.sort([invite.invitee | friends])}} end)
        |> put_flash(:info, "Invitation accepted")}
      _ -> {:noreply, put_flash(socket, :error, "Error when accepting invite")}
    end
  end

  # WARN: We -DO NOT- report that a friend was removed EVER.
  def handle_event("remove_friend", %{"userid" => userid}, socket) do
    IO.inspect("yep, w'ere here")
    current_user = socket.assigns.current_user
    IO.inspect(current_user)
    remove_result = Friendship.remove_friend(current_user, userid)
    case remove_result do
      {:ok, _} ->
          %AsyncResult{result: friends} = socket.assigns.friends
          {:noreply, socket
          |> assign_async(:friends, fn -> {:ok, %{friends: Enum.filter(friends, fn {id, _} -> id == userid end)}} end)
          |> put_flash(:info, "Friend removed")}
      _ -> {:noreply, put_flash(socket, :error, "Error removing friend")}
    end
  end

  defp game_invite(assigns) do
    ~H"""
    <div class="w-1/4 h-full">
      <.modal id="game-invite" show={assigns.show}>
        <h1><strong><%= assigns.invitee_handle %></strong> invites you to a match!</h1>
        <div>
          <.link id="game_invite" href={~p"/lobby/#{assigns.game_id || ""}"}>Go!</.link>
        </div>
      </.modal>
    </div>
    """
  end
end
