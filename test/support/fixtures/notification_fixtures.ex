defmodule StopMyHand.NotificationFixtures do
  use StopMyHand.DataCase

  import StopMyHand.AccountsFixtures
  import StopMyHand.Repo
  alias StopMyHand.Notification

  def create_unread_notification(recipient, title, sent_at \\ NaiveDateTime.utc_now()) do
    IO.inspect(sent_at)
    attrs = %{
      title: title,
      type: "game_invite",
      status: "unread",
      user_id: recipient.id,
      metadata: %{
        invitee: "Waluigi",
        match_id: 1
      },
      inserted_at: sent_at,
      updated_at: sent_at
    }

    Notification.insert_notification(attrs)
  end
end
