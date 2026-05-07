defmodule StopMyHandWeb.MatchTest do
  use StopMyHandWeb.ConnCase

  import Phoenix.LiveViewTest
  import StopMyHand.GameFixtures
  import StopMyHand.AccountsFixtures

  alias StopMyHandWeb.Game.Match

  describe "Match page" do
    test "redirects when the match doesn't exist", %{conn: conn} do
      match = create_match()

      assert {:error, {:redirect, %{to: "/"}}} =
        live(conn |> log_in_user(match.creator), ~p"/match/99999")
    end

    test "redirects when player doesn't belong in the match", %{conn: conn} do
      match = create_match()

      unrelated_user = user_fixture()

      assert {:error, {:redirect, %{to: "/"}}} =
        live(conn |> log_in_user(unrelated_user), ~p"/match/#{match.id}")
    end
  end
end
