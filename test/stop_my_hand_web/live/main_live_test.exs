defmodule StopMyHandWeb.MainLiveTest do
  use StopMyHandWeb.ConnCase
  import Phoenix.LiveViewTest
  import StopMyHand.AccountsFixtures
  import StopMyHand.FriendshipFixtures

  alias StopMyHand.Game
  alias StopMyHand.Cache
  alias StopMyHand.Repo

  @status_indicator_sel "[data-testid='status-indicator']"

  describe "List current user's friends and invites" do
    test "shows nothing when there's no pending invites", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/main")

      refute html =~ "Invites"
    end

    test "shows Invite and a list of items when there are pending invites", %{conn: conn} do
      current_user = user_fixture()
      invite = invite_fixture(current_user.id)

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/main")

      result = render_async(lv)

      assert result =~ "Invites"
      assert result =~ invite.invitee.username
    end

    test "shows Friends label and link to search if there are no friends currently", %{conn: conn} do
      current_user = user_fixture()

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/main")

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

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/main")

      result = render_async(lv)

      assert result =~ "Friends"
      assert result =~ friend1.invitee.username
      assert result =~ friend2.invitee.username
    end

    test "shows dropdown with option to remove the friend", %{conn: conn} do
      current_user = user_fixture()
      {:ok, _} = accepted_invite(current_user.id)

      {:ok, lv, _html} = live(log_in_user(conn, current_user), "/main")

      result = render_async(lv)

      assert result =~ "..."
      assert result =~ "Delete"
    end

    test "online status", %{conn: conn} do
      {user1, user2} = friendship()

      {:ok, lv, _html} = live(log_in_user(conn, user1), "/main")

      result = render_async(lv)

      assert result =~ user2.username
      assert lv |> element("#{@status_indicator_sel}.bg-light") |> has_element?()

      assert Cache.get_friend_id_list(user1.id) == [{user2.id, :offline}]

      {:ok, lv2, _html} = live(log_in_user(conn, user2), "/main")

      result2 = render_async(lv2)

      assert result2 =~ user1.username

      assert lv2 |> element("#{@status_indicator_sel}.bg-accent") |> has_element?()

      send(lv.pid, %{event: "join", payload: {1, {2, user2.id}}})

      assert Cache.get_friend_id_list(user1.id) == [{user2.id, :online}]

      new_result = render_async(lv)

      assert lv |> element("#{@status_indicator_sel}.bg-accent") |> has_element?()

      send(lv.pid, %{event: "leave", payload: {1, {2, user2.id}}})

      final_result = render_async(lv)

      assert final_result =~ user2.username

      assert lv |> element("#{@status_indicator_sel}.bg-light") |> has_element?()

      assert Cache.get_friend_id_list(user1.id) == [{user2.id, :offline}]
    end

    test "game notification", %{conn: conn} do
      {invitee, invited} = friendship()

      {:ok, invited_lv, _htl} = live(log_in_user(conn, invited), "/main")
      Game.create_match(invitee, %{creator_id: invitee.id, players: [%{user_id: invited.id}]})

      result = render_async(invited_lv)

      assert result =~ invitee.username
    end

    test "game notification redirects to lobby", %{conn: conn} do
      {invitee, invited} = friendship()

      {:ok, invited_lv, _htl} = live(log_in_user(conn, invited), "/main")
      {:ok, match} = Game.create_match(invitee, %{creator_id: invitee.id, players: [%{user_id: invited.id}]})

      result = render_async(invited_lv)

      assert result =~ invitee.username

      assert {:error, {:redirect, %{to: "/lobby/"<> match_id}}} = invited_lv |> element("#game_invite") |> render_click()

      assert match_id == "#{match.id}"
    end
  end
end
