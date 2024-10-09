defmodule StopMyHandWeb.ListFriendTest do
  use StopMyHandWeb.ConnCase
  import Phoenix.LiveViewTest
  import StopMyHand.AccountsFixtures
  import StopMyHand.FriendshipFixtures
  alias StopMyHand.Repo

  describe "List current user's friends and invites" do
    test "shows nothing when there's no pending invites", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/list")

      refute html =~ "Invites"
    end

    test "shows Invite and a list of items when there are pending invites", %{conn: conn} do
      current_user = user_fixture()
      invite = invite_fixture(current_user.id)

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/list")

      result = render_async(lv)

      assert result =~ "Invites"
      assert result =~ invite.invitee.username
    end

    test "shows Friends label and link to search if there are no friends currently", %{conn: conn} do
      current_user = user_fixture()

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/list")

      result = render_async(lv)

      assert result =~ "Friends"
      assert result =~ "No friends."

      lv
      |> element(~s|main a:fl-contains("Search for friends!")|)
      |> render_click()

      assert_redirect lv, "/start"
    end

    test "shows Friends and list of friend usernames", %{conn: conn} do
      current_user = user_fixture()

      {:ok, %{invite: invite1}} = accepted_invite(current_user.id)
      {:ok, %{invite: invite2}} = accepted_invite(current_user.id)

      friend1 = Repo.preload(invite1, :invitee)
      friend2 = Repo.preload(invite2, :invitee)

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/list")

      result = render_async(lv)

      assert result =~ "Friends"
      assert result =~ friend1.invitee.username
      assert result =~ friend2.invitee.username
    end
  end
end
