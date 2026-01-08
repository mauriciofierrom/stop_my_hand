defmodule StopMyHandWeb.Notification do
  use StopMyHandWeb, :live_component

  alias StopMyHandWeb.Dropdown

  def render(assigns) do
    ~H"""
    <div>
      <.live_component module={Dropdown} id="notifications">
          <:button class="ml-auto">
              <.icon name={bell_icon(@unread_count)} />
              <%= if @unread_count > 0 do %>
                  <span class="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-3 w-3 flex items-center justify-center">
                  <%= @unread_count %>
                  </span>
              <% end %>
          </:button>
          <%= for {dom_id, notification} <- @notifications do %>
              <.dropdown_item>
                  <%= notification(notification) %>
              </.dropdown_item>
          <% end %>
      </.live_component>
    </div>
    """
  end

  def handle_event("notification_read", %{"id" => notification_id}, socket) do
    send self(), {:mark_notification_read, notification_id}
  end

  defp notification(notification) do
    case notification.type do
      "game_invite" -> game_notification(notification)
      _ -> generic_notification(notification)
    end
  end

  defp game_notification(assigns) do
    ~H"""
    <div id={"notification-#{@id}"} phx-hook="NotificationHover" data-notification-id={@id} class={[@status == "read" && "opacity-50"]}>
      <title>@title</title>
      <section>
        <p>
          <strong><%= @metadata["invitee"] %></strong> <%= gettext("invites you to") %> <a href={~p"/lobby/#{@metadata["match_id"]}"}><%= gettext("a match") %>!</a>
        </p>
      </section>
    </div>
    """
  end

  defp generic_notification(assigns) do
    ~H"""
    <title>@title</title>
    """
  end

  defp bell_icon(unread_count) when unread_count > 0, do: "hero-bell"
  defp bell_icon(unread_count), do: "hero-bell-slash"
end
