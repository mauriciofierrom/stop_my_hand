defmodule StopMyHandWeb.CreateMatchTest do
  use StopMyHandWeb.ConnCase

  import Phoenix.LiveViewTest
  import StopMyHand.FriendshipFixtures

  alias Phoenix.LiveView.AsyncResult
  alias StopMyHandWeb.Game.CreateMatch

  describe "Game creation form modal" do
    test "show friends that are online" do
      {invitee, invited} = friendship()

      friends =
        AsyncResult.ok(%{invitee.id => %{user: invitee, status: :online}})

      assert render_component(CreateMatch, id: 1, friends: friends, current_user: invited) =~ invitee.username
    end

    test "don't show friends that are offline" do
      {invitee, invited} = friendship()

      friends =
        AsyncResult.ok(%{invitee.id => %{user: invitee, status: :offline}})

      refute render_component(CreateMatch, id: 1, friends: friends, current_user: invited) =~ invitee.username
    end

    test "add checked users only", %{conn: conn} do
      {invitee, invited} = friendship()

      {:ok, invited_lv, _html} = live(log_in_user(conn, invited), "/list")

      render_async(invited_lv)

      {:ok, invitee_lv, _html} = live(log_in_user(conn, invitee), "/list")

      send(invitee_lv.pid, %{event: "join", payload: {1, {2, invited.id}}})

      invitee_lv
      |> element("input[type=checkbox][phx-value-userid='#{invited.id}']")
      |> render_click(%{"value" => "on"})

      assert has_element?(invitee_lv, "input[type='hidden'][value='#{invited.id}']")
    end

    test "don't allow creating game if no players are selected" do
      {_invitee, invited} = friendship()

      view = render_component(CreateMatch, id: 1, friends: AsyncResult.ok([]), current_user: invited)

      assert view =~ ~r/<button[^>]*disabled[^>]*>/
    end
  end
end
