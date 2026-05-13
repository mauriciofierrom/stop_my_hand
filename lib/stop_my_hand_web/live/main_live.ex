defmodule StopMyHandWeb.Main do
  @moduledoc """
  The Home page for logged-in users.
  """

  use StopMyHandWeb, :live_view

  alias StopMyHand.Repo
  alias StopMyHand.Friendship
  alias StopMyHand.Accounts
  alias Phoenix.LiveView.AsyncResult
  alias StopMyHandWeb.Friendship.List
  alias StopMyHandWeb.Game.CreateMatch
  alias StopMyHandWeb.Endpoint
  alias StopMyHandWeb.Presence
  alias StopMyHand.Cache

  require Logger

  @notification "notification"

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-[4fr_1fr]">
      <div class="flex flex-col items-start gap-4">
        <h1 class="text-8xl mb-20"><%= gettext("Stop My Hand") %></h1>
        <button class="btn btn-blue text-5xl" id="create-match-btn" phx-click={show_modal("create-match-modal")}><%= gettext("Start Match") %>!</button>
        <.live_component module={CreateMatch} id="create_match" friends={@friends} current_user={assigns.current_user} />
        <.game_invite game_id={@game_invite.game_id} invitee_handle={@game_invite.invitee_handle} show={@game_invite.show} />
      </div>
      <div class="flex gap-2 justify-between">
        <div class="flex-1">
          <List.friend_list current_user={assigns.current_user} friends={@friends} invites={@invites}/>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    Endpoint.subscribe("#{@notification}:#{current_user.id}")

    {:ok, socket
    |> assign(:game_invite, %{game_id: nil, invitee_handle: "", show: false})
    |> assign_async(:invites, fn -> {:ok, %{invites: Friendship.get_pending_invites(current_user.id)}} end)
    |> assign(:friends, AsyncResult.ok([]))
    |> start_async(:fetch_friends, fn -> Friendship.get_friends(current_user.id) end)
    |> assign(:show_create_match_modal, false)
    }
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

  def handle_async(:fetch_friends, {:exit, reason}, socket) do
    Logger.error("Error fetching friends #{inspect(reason)}", user_id: socket.assigns.current_user.id)

    {:noreply, socket
     |> assign(:friends, AsyncResult.failed(%AsyncResult{}, reason))
     |> put_flash(:error, "Friends couldn't be loaded")
    }
  end

  def handle_info(%{event: "invite_accepted", payload: %{invited_id: invited_id}}, socket) do
    with %AsyncResult{ok?: true, result: invites} <- socket.assigns.invites,
        %AsyncResult{ok?: true, result: friends} <- socket.assigns.friends do

      invited = Accounts.get_user!(invited_id)

      {:noreply, socket
      |> assign(:invites, AsyncResult.ok(Enum.filter(invites, &(&1.invitee.id != invited_id))))
      |> assign(:friends, AsyncResult.ok(Enum.sort([invited | friends])))
      |> put_flash(:info, "Invitation accepted by: #{invited.username}")}
    else
      _ ->
        Logger.error("Error receiving invitation acceptance", invited_id: invited_id, recipient_id: socket.assigns.current_user.id)
        {:noreply, socket |> put_flash(:error, "Failed to receive accepted invitation")}
    end
  end

  def handle_info(%{event: "invite_received", payload: %{invite_id: invite_id}}, socket) do
    case socket.assigns.invites do
      %AsyncResult{ok?: true, result: invites} ->
        case Friendship.get_invite_with_invitee(invite_id) do
          nil ->
            Logger.error("Error fetching invite", invite_id: invite_id, user_id: socket.assigns.current_user.id)
            {:noreply, socket |> put_flash(:error, "Failed to fetch invite")}
          invite ->
            {:noreply, socket
            |> assign(:invites, AsyncResult.ok(Enum.sort([invite | invites])))
            |> put_flash(:info, "Invitation received")}
        end
      _ ->
        Logger.error("Error receiving invitation", invite_id: invite_id, user_id: socket.assigns.current_user.id)
        {:noreply, socket |> put_flash(:error, "Failed to receive invitation")}
    end
  end

  def handle_info(%{event: "join", payload: {_, {_, user_id}}}, socket) do
    current_user = socket.assigns.current_user

    case socket.assigns.friends do
      %AsyncResult{ok?: true, result: friends} ->
        new_friends = handle_presence(current_user, friends, user_id, :online)
        {:noreply, assign(socket, :friends, AsyncResult.ok(new_friends))}
      _ ->
        Logger.error("Error when adding joining friend", joining_id: user_id, user_id: current_user.id)
        {:noreply, socket}
    end
  end

  def handle_info(%{event: "leave", payload: {_, {_, user_id}}}, socket) do
    current_user = socket.assigns.current_user

    case socket.assigns.friends do
      %AsyncResult{ok?: true, result: friends} ->
        new_friends = handle_presence(current_user, friends, user_id, :offline)
        {:noreply, assign(socket, :friends, AsyncResult.ok(new_friends))}
      _ ->
        Logger.error("Error when removing leaving friend", joining_id: user_id, user_id: current_user.id)
        {:noreply, socket}
    end
  end

  def handle_info(%{event: "game_invite", payload: notification_id}, socket) do
    case Repo.get(StopMyHand.Notification.Notification, notification_id) do
      nil ->
        Logger.error("Error fetching notification", notification_id: notification_id, user_id: socket.assigns.current_user.id)
        {:noreply, socket}
      notification ->
        {:noreply, socket
        |> assign(:game_invite, %{
              game_id: notification.metadata["match_id"],
              invitee_handle: notification.metadata["invitee"],
              show: true})
        }
    end
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
    current_user = socket.assigns.current_user
    case Friendship.get_invite_with_invitee(inviteid) do
      nil ->
        Logger.error("Error fetching invitation", invite_id: inviteid, user_id: current_user.id)
        {:noreply, put_flash(socket, :error, "Error fetching invitation")}
      invite ->
        accept_result = Friendship.accept_invite(invite)
        case accept_result do
          {:ok, _} ->

            with %AsyncResult{ok?: true, result: invites} <- socket.assigns.invites,
                %AsyncResult{ok?: true, result: friends} <- socket.assigns.friends do
              Endpoint.broadcast("friends:#{invite.invitee_id}", "invite_accepted", %{invited_id: current_user.id})

              {:noreply, socket
              |> assign(:invites, AsyncResult.ok(Enum.filter(invites, &(&1.invitee.id != invite.invitee.id))))
              |> assign(:friends, AsyncResult.ok(Enum.sort([invite.invitee | friends])))
              |> put_flash(:info, "Invitation accepted")}
            else
              _ ->
                Logger.error("Error fetching invites & friends", user_id: current_user.id)
                {:noreply, put_flash(socket, :error, "Error when accepting invite")}
            end
          _ ->
            Logger.error("Error accepting invite", invite_id: inviteid, user_id: current_user.id)
            {:noreply, put_flash(socket, :error, "Error when accepting invite")}
        end
    end
  end

  # WARN: We -DO NOT- report that a friend was removed EVER.
  def handle_event("remove_friend", %{"userid" => userid}, socket) do
    current_user = socket.assigns.current_user
    remove_result = Friendship.remove_friend(current_user, userid)
    case remove_result do
      {:ok, _} ->
        case socket.assigns.friends do
          %AsyncResult{ok?: true, result: friends} ->
            {:noreply, socket
            |> assign(:friends, AsyncResult.ok(Enum.filter(friends, fn {id, _} -> id != String.to_integer(userid) end)))
            |> put_flash(:info, "Friend removed")
            }
          _ ->
            Logger.error("Error when removing friend", friend_id: userid, user_id: current_user.id)
            {:noreply, socket |> put_flash(:error, "Failed to remove friend")}
        end
      _ ->
        Logger.error("Error removing friend", friend_id: userid, user_id: current_user.id)
        {:noreply, put_flash(socket, :error, "Error removing friend")}
    end
  end

  defp game_invite(assigns) do
    ~H"""
    <div class="w-1/4 h-full">
      <.modal id="game-invite" show={assigns.show}>
        <h1><strong><%= assigns.invitee_handle %></strong> <%= gettext("invites you to") %> <%= gettext("a match") %>!</h1>
        <div>
          <.link id="game_invite" href={~p"/lobby/#{assigns.game_id || ""}"}><%= gettext("Go") %>!</.link>
        </div>
      </.modal>
    </div>
    """
  end
end
