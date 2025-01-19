defmodule StopMyHandWeb.LobbyTest do
  use StopMyHandWeb.ConnCase

  import Phoenix.LiveViewTest
  import StopMyHand.GameFixtures

  describe "Lobby page" do
    test "shows invited players with their status", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      refute result =~ "online"
      assert result =~ "offline"

      Enum.each(match.players, fn player -> assert result =~ player.user.username end)

      {:ok, lv_player, _html} = live(log_in_user(conn, first_player.user), "/lobby/#{match.id}")

      result = render_async(lv_player)

      assert result =~ "online"
      assert result =~ "Me"
    end

    test "when an invited player joins the lobby their status is updated to online", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      refute result =~ "online"

      send(lv.pid, %{event: "join", payload: {1, {2, first_player.user.id}}})

      new_result = render_async(lv)

      assert new_result =~ "online"
    end

    test "when an invited player leaves the lobby their status is updated to offline", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, first_player_lv, _html} = live(log_in_user(conn, first_player.user), "/lobby/#{match.id}")

      _first_result = render_async(first_player_lv)

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      assert result =~ "online"

      send(lv.pid, %{event: "leave", payload: {1, {2, first_player.user.id}}})

      new_result = render_async(lv)

      refute new_result =~ "online"
    end

    test "when no invited player is online the Start button is disabled", %{conn: conn} do
      match = create_match()
      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      refute result =~ "online"
      assert result =~ ~r/<button[^>]*disabled[^>]*>/
    end

    @tag :focus
    test "when there's at least one invited player online the Start butotn is enabled", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, first_player_lv, _html} = live(log_in_user(conn, first_player.user), "/lobby/#{match.id}")

      _first_result = render_async(first_player_lv)

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      assert result =~ "online"
      refute result =~ ~r/<button[^>]*disabled[^>]*>/
    end
  end
end
