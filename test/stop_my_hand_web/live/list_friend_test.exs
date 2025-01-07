defmodule StopMyHandWeb.ListFriendTest do
  use StopMyHandWeb.ConnCase
  import Phoenix.LiveViewTest
  import StopMyHand.AccountsFixtures
  import StopMyHand.FriendshipFixtures

  alias StopMyHand.Repo
  alias StopMyHand.Cache

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

    test "shows dropdown with option to remove the friend", %{conn: conn} do
      current_user = user_fixture()
      {:ok, _} = accepted_invite(current_user.id)

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/list")

      result = render_async(lv)

      assert result =~ "..."
      assert result =~ "Delete"
    end

    @tag :focus
    test "online status", %{conn: conn} do
      {user1, user2} = friendship()

      {:ok, lv, _html} = live(log_in_user(conn, user1), "/list")

      result = render_async(lv)

      assert result =~ user2.username
      assert result =~ "offline"

      assert Cache.get_friend_id_list(user1.id) == [{user2.id, :offline}]

      {:ok, lv2, _html} = live(log_in_user(conn, user2), "/list")

      result2 = render_async(lv2)

      assert result2 =~ user1.username
      assert result2 =~ "online"

      send(lv.pid, %{event: "join", payload: {1, {2, user2.id}}})
      assert Cache.get_friend_id_list(user1.id) == [{user2.id, :online}]

      new_result = render_async(lv)

      assert new_result =~ "online"

      send(lv.pid, %{event: "leave", payload: {1, {2, user2.id}}})

      final_result = render_async(lv)

      assert final_result =~ user2.username
      assert final_result =~ "offline"
      assert Cache.get_friend_id_list(user1.id) == [{user2.id, :offline}]
    end
  end
end
