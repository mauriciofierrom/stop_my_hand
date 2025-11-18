defmodule StopMyHandWeb.Friendship.List do
  use StopMyHandWeb, :html

  alias Phoenix.LiveView.AsyncResult
  alias StopMyHandWeb.Dropdown
  alias Phoenix.LiveView.JS
  alias StopMyHandWeb.Friendship.Search

  def friend_list(assigns) do
    ~H"""
    <div class="flex flex-cols">
      <div id="friend_list" class="w-full h-full border border-stroke flex flex-column gap-2 p-4 rounded-xs shadow-md">
        <%= if assigns.invites.result && !(Enum.empty? assigns.invites.result) do %>
          <div class="w-full">
            <.async_result :let={invites} assign={assigns.invites}>
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
          </div>
        <% end %>

        <div class="w-full">
          <div class="flex flex-row">
            <h1 class="text-accent mb-2 text-2xl">Friends</h1>
            <button data-testid="search-friend-button" -class="ml-auto" phx-click={show_modal("search-friend")}>
              <.icon name="hero-magnifying-glass" />
            </button>
          </div>
          <.async_result :let={friends} assign={assigns.friends}>
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
        </div>
      </div>
      <.live_component module={Search} id="search-friend-modal" current_user={assigns.current_user}/>
    </div>
    """
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
        "flex flex-row border border-stroke shadow-md p-3"
    ]}>
      <div class="basis--2/3 flex flex-row items-baseline gap-2 text-lg">
        <%= assigns.friend.user.username %>
        <.status_indicator status={assigns.friend.status} />
        <.live_component module={Dropdown} id={assigns.friend.user.id}>
          <:button class="ml-auto">
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
end
