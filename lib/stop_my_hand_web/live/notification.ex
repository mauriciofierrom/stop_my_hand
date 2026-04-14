defmodule StopMyHandWeb.Notification do
  use StopMyHandWeb, :live_view

  alias StopMyHandWeb.Dropdown
  alias StopMyHandWeb.Endpoint

  @notification "notification"

  def mount(_params, %{"user_id" => user_id}, socket) do
    notifications = StopMyHand.Notification.fetch_notifications(user_id)
    unread_count = Enum.count(notifications, & &1.status == "unread")

    Endpoint.subscribe("#{@notification}:#{user_id}")

    {:ok, socket
     |> assign(:unread_count, unread_count)
     |> stream(:notifications, notifications), layout: false
    }
  end

  def render(assigns) do
    ~H"""
    <div>
      <.live_component module={Dropdown} id="notifications-dropdown">
          <:button class="ml-auto">
              <.icon name={bell_icon(@unread_count)} />
              <%= if @unread_count > 0 do %>
                  <span class="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-3 w-3 flex items-center justify-center">
                  <%= @unread_count %>
                  </span>
              <% end %>
          </:button>
          <div id="notifications" phx-update="stream">
            <.dropdown_item :for={{dom_id, notification} <- @streams.notifications} id={dom_id}>
              <%= notification(notification) %>
            </.dropdown_item>
          </div>
      </.live_component>
    </div>
    """
  end

  def handle_info(%{event: "game_invite", payload: notification_id}, socket) do
    notification = StopMyHand.Repo.get!(StopMyHand.Notification.Notification, notification_id)

    {:noreply, socket
     |> update(:unread_count, &(&1 + 1))
     |> stream_insert(:notifications, notification, at: 0)
    }
  end

  def handle_event("notification_read", %{"id" => notification_id}, socket) do
    case StopMyHand.Notification.mark_as_read(String.to_integer(notification_id)) do
      {:ok, updated_notification} ->
        {:noreply, socket
         |> assign(:unread_count, max(socket.assigns.unread_count - 1, 0))
         |> stream_insert(:notifications, updated_notification, update_only: true)
        }
      {:error, _} -> {:noreply, socket}
    end
  end

  defp notification(notification) do
    case notification.type do
      "game_invite" -> game_notification(notification)
      _ -> generic_notification(notification)
    end
  end

  defp game_notification(assigns) do
    ~H"""
    <div id={"inner-notification-#{@id}"} phx-hook="NotificationHover" data-read={@status} data-notification-id={@id} class={[@status == "read" && "opacity-50"]}>
      <title><%= @title %></title>
      <section>
        <p>
          <strong><%= @metadata["invitee"] %></strong> <%= gettext("invites you to") %> <a href={~p"/lobby/#{@metadata["match_id"]}"}><%= gettext("a match") %>!</a>
          <%= @inserted_at %>
        </p>
      </section>
    </div>
    """
  end

  defp generic_notification(assigns) do
    ~H"""
    <title><%= @notification.title %></title>
    """
  end

  defp bell_icon(unread_count) when unread_count > 0, do: "hero-bell"
  defp bell_icon(_unread_count), do: "hero-bell-slash"
end
