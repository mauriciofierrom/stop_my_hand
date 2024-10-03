defmodule StopMyHandWeb.SendInviteLiveTest do
  use StopMyHandWeb.ConnCase
  import Phoenix.LiveViewTest
  import StopMyHand.AccountsFixtures

  describe "Search people to invite" do
    test "shows empty result as default", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/start")

      assert html =~ "No results"
    end

    test "show invite button and username when a match is found", %{conn: conn} do
      current_user = user_fixture()
      user_to_invite = user_fixture()

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/start")

      lv
        |> element("#search_friend")
        |> render_change(%{"search_friend" => user_to_invite.username})

      # Here to account for phx-debounce
      # TODO: Maybe it makes sense to disable phx-debounce when testing?
      Process.sleep(600)

      result = render(lv)

      assert result =~ user_to_invite.username
      assert result =~ "Invite"
    end

    test "show empty result message when no match is found", %{conn: conn} do
      current_user = user_fixture()
      user_to_invite = user_fixture(%{username: "steppenwolf"})

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/start")

      lv
        |> element("#search_friend")
        |> render_change(%{"search_friend" => "hermann"})

      # Here to account for phx-debounce
      # TODO: Maybe it makes sense to disable phx-debounce when testing?
      Process.sleep(600)

      result = render(lv)

      refute result =~ user_to_invite.username
      refute result =~ "Invite"
    end
  end
end
