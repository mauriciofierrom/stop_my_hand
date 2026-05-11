defmodule StopMyHandWeb.LobbyTest do
  use StopMyHandWeb.ConnCase

  import Mox

  import Phoenix.LiveViewTest
  import StopMyHand.GameFixtures
  import StopMyHand.AccountsFixtures

  @status_indicator_sel "[data-testid='status-indicator']"

  setup :verify_on_exit!

  describe "Lobby page" do
    test "redirects when the match doesn't exist", %{conn: conn} do
      match = create_match()

      assert {:error, {:redirect, %{to: "/"}}} =
        live(conn |> log_in_user(match.creator), ~p"/lobby/99999")
    end

    test "redirects when player doesn't belong in the match", %{conn: conn} do
      match = create_match()

      unrelated_user = user_fixture()

      assert {:error, {:redirect, %{to: "/"}}} =
        live(conn |> log_in_user(unrelated_user), ~p"/lobby/#{match.id}")
    end

    test "shows invited players with their status", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      assert lv
        |> element("#{@status_indicator_sel}.bg-accent") |> has_element?()

      assert lv
        |> element("#{@status_indicator_sel}.bg-light") |> has_element?()

      Enum.each(match.players, fn player -> assert result =~ player.user.username end)

      {:ok, lv_player, _html} = live(log_in_user(conn, first_player.user), "/lobby/#{match.id}")

      result = render_async(lv_player)

      assert lv_player
        |> element("#{@status_indicator_sel}.bg-accent") |> has_element?()

      assert result =~ "Me"
    end

    test "when an invited player joins the lobby their status is updated to online", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      offline = Floki.find(result, "#{@status_indicator_sel}.bg-light")
      online = Floki.find(result, "#{@status_indicator_sel}.bg-accent")

      assert (length offline) == 2
      assert (length online) == 1

      send(lv.pid, %{event: "join", payload: {1, {2, first_player.user.id}}})

      new_result = render_async(lv)

      offline = Floki.find(new_result, "#{@status_indicator_sel}.bg-light")
      online = Floki.find(new_result, "#{@status_indicator_sel}.bg-accent")

      assert (length offline) == 1
      assert (length online) == 2
    end

    test "when an invited player leaves the lobby their status is updated to offline", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, first_player_lv, _html} = live(log_in_user(conn, first_player.user), "/lobby/#{match.id}")

      _first_result = render_async(first_player_lv)

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      online = Floki.find(result, "#{@status_indicator_sel}.bg-accent")

      assert (length online) == 2

      send(lv.pid, %{event: "leave", payload: {1, {2, first_player.user.id}}})

      new_result = render_async(lv)

      online = Floki.find(new_result, "#{@status_indicator_sel}.bg-accent")

      assert (length online) == 1
    end

    test "when no invited player is online the Start button is disabled", %{conn: conn} do
      match = create_match()
      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      online = Floki.find(result, "#{@status_indicator_sel}.bg-accent")

      # Only the creator of the match is always online
      assert length(online) == 1
      assert Floki.find(result, "button[disabled]") != []
    end

    test "when there's at least one invited player online the Start button is enabled", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, first_player_lv, _html} = live(log_in_user(conn, first_player.user), "/lobby/#{match.id}")

      _first_result = render_async(first_player_lv)

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      online = Floki.find(result, "#{@status_indicator_sel}.bg-accent")

      assert length(online) == 2
      assert Floki.find(result, "button[disabled]") == []
    end

    test "redirects when the match driver fails to start", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, first_player_lv, _html} = live(log_in_user(conn, first_player.user), "/lobby/#{match.id}")

      _first_result = render_async(first_player_lv)

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      expect(StopMyHand.MatchSupervisor.Mock, :start_match, fn _ -> {:error, "Some reason"} end)

      lv |> element("button", "Play!") |> render_click()

      flash = assert_redirect lv, "/"
      assert flash["error"] == "Match could not get started"
    end
  end
end
