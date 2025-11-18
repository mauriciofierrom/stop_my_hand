defmodule StopMyHandWeb.LobbyTest do
  use StopMyHandWeb.ConnCase

  import Phoenix.LiveViewTest
  import StopMyHand.GameFixtures

  @status_indicator_sel "[data-testid='status-indicator']"

  describe "Lobby page" do
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

      send(lv.pid, %{event: "join", payload: {1, {2, first_player.user.id}}})

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

    @tag :focus
    test "when no invited player is online the Start button is disabled", %{conn: conn} do
      match = create_match()
      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      online = Floki.find(result, "#{@status_indicator_sel}.bg-accent")

      # Only the creator of the match is always online
      assert length(online) == 1
      assert Floki.find(result, "button[disabled]") != []
    end

    @tag :focus
    test "when there's at least one invited player online the Start button is enabled", %{conn: conn} do
      match = create_match()
      [first_player|_rest] = match.players

      {:ok, first_player_lv, _html} = live(log_in_user(conn, first_player.user), "/lobby/#{match.id}")

      _first_result = render_async(first_player_lv)

      {:ok, lv, _html} = live(log_in_user(conn, match.creator), "/lobby/#{match.id}")

      result = render_async(lv)

      online = Floki.find(result, "#{@status_indicator_sel}.bg-accent")
      disabled_button = Floki.find(result, "button[disabled]")

      assert length(online) == 2
      assert Floki.find(result, "button[disabled]") == []
    end
  end
end
