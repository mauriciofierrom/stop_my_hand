defmodule StopMyHand.Notification do
  @moduledoc """
  The Notification context.
  """

  import Ecto.Query, warn: false

  alias StopMyHand.Repo
  alias StopMyHandWeb.Endpoint
  alias StopMyHand.Notification.Notification

  @notification "notification"
  @game_invite_title "Game invite!"

  def notify_players(invitee_handle, match) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    entries = Enum.map(match.players, fn player ->
      metadata = %{
        invitee: invitee_handle,
        match_id: match.id
      }
      %{
        title: @game_invite_title,
        type: "game_invite",
        status: "unread",
        user_id: player.user_id,
        metadata: metadata,
        inserted_at: now,
        updated_at: now
      }
    end)

    case Repo.insert_all(Notification, entries, returning: true) do
      {count, notifications} when count > 0 ->
        {:ok, notifications}
      {0, _} ->
        Logger.warning("Failed to insert notifications for match #{match.id}")
        {:error, "Failed to notify players"}
    end
  end

  def broadcast_notifications(notifications) do
    Enum.each(notifications, fn notification ->
      Endpoint.broadcast("#{@notification}:#{notification.user_id}",
        "game_invite",
        notification.id
      )
    end)
    :ok
  end

  def fetch_notifications(user_id) do
    Notification
    |> where(user_id: ^user_id)
    |> order_by(desc: :inserted_at)
    |> limit(5)
    |> Repo.all()
  end

  def mark_as_read(notification_id) do
    case Repo.get(Notification, notification_id) do
      nil -> {:error, "Notification not found"}
      notification ->
        notification
        |> Notification.changeset(%{status: "read"})
        |> Repo.update()
    end
  end

  defp insert_notification(attrs) do
    %Notification{}
    |> Notification.mark_read_changeset(attrs)
    |> Repo.insert()
  end
end
