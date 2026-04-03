defmodule StopMyHand.MatchDriverTest do
  use StopMyHand.DataCase, async: false

  alias StopMyHand.MatchDriver
  alias StopMyHandWeb.Endpoint
  import Mox

  import StopMyHand.GameFixtures

  @match_topic "match"
  @category_amount 6

  setup :set_mox_global
  setup :verify_on_exit!

  describe "MatchDriver" do
    setup do
      Mox.stub_with(StopMyHand.Scheduler.Mock, StopMyHand.Scheduler.Test)

      match = create_match()
      players = [match.creator|(for player <- match.players, do: player.user)]
      {:ok, pid}  = MatchDriver.start_link(
        %{players: players, match_id: match.id}
      )
      {:ok, %{match: match, match_driver_pid: pid}}
    end

    test "match starts when there's at least two players", context do
      Endpoint.subscribe("#{@match_topic}:#{context[:match].id}")

      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      assert_receive %Phoenix.Socket.Broadcast{event: "game_start", payload: %{round: 1}}
    end

    test "match starts when there's more than two players but not full quorum", context do
      Endpoint.subscribe("#{@match_topic}:#{context[:match].id}")

      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 1))

      send(context[:match_driver_pid], :game_start)

      assert_receive %Phoenix.Socket.Broadcast{event: "game_start", payload: %{round: 1}}
    end

    test "match starts when there's full quorum", context do
      Endpoint.subscribe("#{@match_topic}:#{context[:match].id}")

      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 1))

      send(context[:match_driver_pid], :game_start)

      assert_receive %Phoenix.Socket.Broadcast{event: "game_start", payload: %{round: 1}}
    end

    test "match driver reports state of match as normal when the match is waiting for players to join", context do
      MatchDriver.add_player(context[:match].id, context[:match].creator)

      assert match?({:normal, _}, MatchDriver.get_match_state(context[:match].id))
    end

    test "match driver reports state of the match as ongoing", context do
      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 1))

      send(context[:match_driver_pid], :game_start)
      assert match?({:ongoing, _}, MatchDriver.get_match_state(context[:match].id))
    end

    test "triggers end of round", context do
      Endpoint.subscribe("#{@match_topic}:#{context[:match].id}")

      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      MatchDriver.finish_round(context[:match].id)

      assert_receive %Phoenix.Socket.Broadcast{event: "round_finished", payload: %{}}
    end

    test "updates players answers", context do
      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      player = Enum.at(context[:match].players, 0)
      player_id = player.user.id

      MatchDriver.finish_round(context[:match].id)

      MatchDriver.report_player_answers(context[:match].id, player_id, [{"name", "some"}, {"animal", "sad"}])
      player_data = MatchDriver.get_player_data(context[:match].id)

      assert match?(%{^player_id => %{answers: %{name: %{value: "some"}, animal: %{value: "sad"}}}}, player_data)
    end

    test "when all active player's answers is received we continue to review", context do
      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      creator = context[:match].creator
      creator_id = creator.id

      MatchDriver.finish_round(context[:match].id)

      MatchDriver.report_player_answers(context[:match].id, creator_id, [{"name", "simple"}, {"animal", "song"}])

      player = Enum.at(context[:match].players, 0)
      player_id = player.user.id

      MatchDriver.report_player_answers(context[:match].id, player_id, [{"name", "some"}, {"animal", "sad"}])

      other_player = Enum.at(context[:match].players, 1)
      other_player_id = other_player.user.id

      MatchDriver.report_player_answers(context[:match].id, other_player_id, [{"name", "silence"}, {"animal", "suture"}])

      {:ongoing, %{player_data: player_data, game_status: game_status}} =
        MatchDriver.get_match_state(context[:match].id)

      assert match?(%{^player_id =>
          %{answers: %{name: %{value: "some"}, animal: %{value: "sad"}}},
          ^creator_id =>
          %{answers: %{name: %{value: "simple"}, animal: %{value: "song"}}},
          ^other_player_id =>
          %{answers: %{name: %{value: "silence"}, animal: %{value: "suture"}}}},
        player_data)

      assert game_status == :in_review
    end

    test "when answer reporting timeout is reached we continue to review with
the reported answers only", context do
      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      player = Enum.at(context[:match].players, 0)
      player_id = player.user.id

      MatchDriver.finish_round(context[:match].id)

      MatchDriver.report_player_answers(context[:match].id, player_id, [{"name", "some"}, {"animal", "sad"}])

      send(context[:match_driver_pid], :answers_timeout)

      {:ongoing, %{player_data: player_data, game_status: game_status}} =
        MatchDriver.get_match_state(context[:match].id)

      assert match?(%{^player_id => %{answers: %{name: %{value: "some"}, animal: %{value: "sad"}}}}, player_data)
      assert game_status == :in_review
    end

    test "receives player review and updates the player data", context do
      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      player = Enum.at(context[:match].players, 0)
      player_id = player.user.id

      MatchDriver.report_player_answers(context[:match].id, player_id, [{"name", "some"}])

      MatchDriver.finish_round(context[:match].id)

      send(context[:match_driver_pid], :answers_timeout)

      creator_id = context[:match].creator.id

      MatchDriver.report_review(context[:match].id, %{reviewer_id: creator_id, player_id: player_id, result: :accepted})

      player_data = MatchDriver.get_player_data(context[:match].id)

      assert match?(%{^player_id => %{answers: %{name: %{value: "some", reviews: %{^creator_id => :accepted}}}}}, player_data)
    end

    test "on review timeout the next category enters review", context do
      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      player = Enum.at(context[:match].players, 0)
      player_id = player.user.id

      MatchDriver.report_player_answers(context[:match].id, player_id, [{"name", "some"}])

      MatchDriver.finish_round(context[:match].id)

      send(context[:match_driver_pid], :answers_timeout)

      {:ongoing, %{current_category: previous_category}} =
        MatchDriver.get_match_state(context[:match].id)

      assert previous_category == :name

      # TODO: Gotta centralized the category list as a single source of truth
      send(context[:match_driver_pid], {:review_timeout, 0})

      {:ongoing, %{current_category: next_category}} =
        MatchDriver.get_match_state(context[:match].id)

      assert next_category == :last_name
    end

    test "when finishing reviewing shares scores to players", context do
      Endpoint.subscribe("#{@match_topic}:#{context[:match].id}")

      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      player = Enum.at(context[:match].players, 0)
      player_id = player.user.id

      MatchDriver.report_player_answers(context[:match].id, player_id, [{"name", "some"}])

      MatchDriver.finish_round(context[:match].id)

      send(context[:match_driver_pid], :answers_timeout)

      send(context[:match_driver_pid], {:review_timeout, @category_amount + 1})

      {:ongoing, %{game_status: game_status}} =
        MatchDriver.get_match_state(context[:match].id)

      assert game_status == :showing_scores
      assert_receive %Phoenix.Socket.Broadcast{event: "show_scores", payload: %{}}
    end

    test "after showing scores it updates the match scores and starts next round countdown", context do
      Endpoint.subscribe("#{@match_topic}:#{context[:match].id}")

      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      player = Enum.at(context[:match].players, 0)
      player_id = player.user.id

      MatchDriver.finish_round(context[:match].id)

      MatchDriver.report_player_answers(context[:match].id, player_id, [{"name", "some"}])

      send(context[:match_driver_pid], :answers_timeout)

      creator_id = context[:match].creator.id

      MatchDriver.report_review(context[:match].id, %{reviewer_id: creator_id, player_id: player_id, result: :accepted})

      send(context[:match_driver_pid], {:review_timeout, @category_amount + 1})

      send(context[:match_driver_pid], :show_scores_timeout)

      assert_receive %Phoenix.Socket.Broadcast{event: "next_round"}
    end

    test "starts the next round with a new letter", context do
      Endpoint.subscribe("#{@match_topic}:#{context[:match].id}")

      MatchDriver.add_player(context[:match].id, context[:match].creator)
      MatchDriver.add_player(context[:match].id, Enum.at(context[:match].players, 0))

      send(context[:match_driver_pid], :game_start)

      player = Enum.at(context[:match].players, 0)
      player_id = player.user.id

      MatchDriver.finish_round(context[:match].id)

      MatchDriver.report_player_answers(context[:match].id, player_id, [{"name", "some"}])

      send(context[:match_driver_pid], :answers_timeout)

      creator_id = context[:match].creator.id

      MatchDriver.report_review(context[:match].id, %{reviewer_id: creator_id, player_id: player_id, result: :accepted})

      send(context[:match_driver_pid], {:review_timeout, @category_amount + 1})
      send(context[:match_driver_pid], :show_scores_timeout)

      {:ongoing, %{current_letter: current_letter, round_number: current_round_number}} = MatchDriver.get_match_state(context[:match].id)
      send(context[:match_driver_pid], :next_round_timeout)

      assert_receive %Phoenix.Socket.Broadcast{event: "round_start", payload: payload}
      assert payload.round == current_round_number + 1
      refute payload.letter == current_letter
    end

    test "review timeout is proportional to number of active player" do
      match = create_match()
      players = [match.creator|(for player <- match.players, do: player.user)]

      {:ok, pid} = MatchDriver.start_link(
        %{players: players, match_id: match.id}
      )

      MatchDriver.add_player(match.id, match.creator)
      MatchDriver.add_player(match.id, Enum.at(match.players, 0))
      MatchDriver.add_player(match.id, Enum.at(match.players, 1))

      send(pid, :game_start)

      player = Enum.at(match.players, 0)
      player_id = player.user.id

      MatchDriver.finish_round(match.id)
      MatchDriver.report_player_answers(match.id, player_id, [{"name", "some"}])

      send(pid, :answers_timeout)

      expect(StopMyHand.Scheduler.Mock, :send_after, fn _pid, {:review_timeout, _idx}, timeout ->
        assert ceil(timeout / Application.get_env(:stop_my_hand, :timeouts)[:review]) == 3
        :ok
      end)

      {:ongoing, match_state} = MatchDriver.get_match_state(match.id)

      assert match_state.game_status == :in_review
    end
  end
end
