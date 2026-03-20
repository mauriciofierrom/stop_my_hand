defmodule StopMyHandWeb.NotificationTest do
  use StopMyHandWeb.ConnCase
  import Phoenix.LiveViewTest

  import StopMyHand.AccountsFixtures
  import StopMyHand.NotificationFixtures

  alias StopMyHandWeb.Notification

  describe "Show game notifications" do
    test "shows the notifications ordered descending by sent time", %{conn: conn} do
      user = user_fixture()

      now = NaiveDateTime.utc_now()
      later = NaiveDateTime.add(now, 5)

      {:ok, _notif1} = create_unread_notification(user, "Notif 1", now)
      {:ok, _notif2} = create_unread_notification(user, "Notif 2", later)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live_isolated(Notification, session: %{"user_id" => user.id})

      [first, second] = html |> Floki.parse_document!() |> Floki.find("[id^='notifications-']")

      assert first |> Floki.text() =~ "Notif 2"
      assert second |> Floki.text() =~ "Notif 1"
    end

    test "marks notification as read in place", %{conn: conn} do
      user = user_fixture()

      now = NaiveDateTime.utc_now()
      later = NaiveDateTime.add(now, 5)

      {:ok, notif1} = create_unread_notification(user, "Notif 1", now)
      {:ok, _notif2} = create_unread_notification(user, "Notif 2", later)

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live_isolated(Notification, session: %{"user_id" => user.id})

      [first, second] = html |> Floki.parse_document!() |> Floki.find("[id^='notifications-']")

      assert first |> Floki.text() =~ "Notif 2"
      assert second |> Floki.text() =~ "Notif 1"

      render_hook(lv, "notification_read", %{id: "#{notif1.id}"})

      new_html = render_async(lv)

      [new_first, new_second] = new_html |> Floki.parse_document!() |> Floki.find("[id^='notifications-']")

      assert new_first |> Floki.text() =~ "Notif 2"
      assert new_second |> Floki.text() =~ "Notif 1"

      [inner_first, inner_second] = new_html |> Floki.parse_document!() |> Floki.find("[id^='inner-notification-']")

      assert "opacity-50" in Floki.attribute(inner_second, "class")
      refute "opacity-50" in Floki.attribute(inner_first, "class")
    end
  end
end
