defmodule StopMyHand.MatchDriver do
  @moduledoc """
  A GenServer to drive the match and its rounds
  """
  use GenServer

  alias StopMyHandWeb.Endpoint
  alias StopMyHand.Game.Score

  @quorum_timeout 45_000
  @game_start_timeout 1_000
  @answers_timeout 10_000
  @base_review_timeout Application.compile_env(:stop_my_hand, [:timeouts, :review])
  @next_round_timeout 5_000
  @match_topic "match"
  @countdown 3
  @round_timeout (@countdown * 1_000) + 180_000
  @categories [:name, :last_name, :city, :color, :animal, :thing]

  @doc """
  Initialize the `MatchDriver` with the `match` id and the `Scheduler` to use.

  Scheduler is used to determine how the genserver will handle timeouts for testing purposes.
  The default implementation calls `send_after/3`.
  """
  def start_link(%{players: players, match_id: match_id}) do
    GenServer.start_link(__MODULE__, {players, match_id}, name: via_tuple(match_id))
  end

  def init({expected_players, match_id}) do
    {starting_letter, alphabet} = pick_letter_from(make_alphabet())

    scheduler().send_after(self(), :no_quorum, @quorum_timeout)
    player_data = Score.default_player_data(expected_players)

    initial_state = %{
      match_id: match_id,
      alphabet: alphabet,
      round: 1,
      letter: starting_letter,
      expected: expected_players,
      joined: [],
      pending: [],
      game_status: :init,
      answers: %{},
      cat_index: 0,
      players_answered: [],
      player_data: player_data,
      score: (for expected_player <- expected_players, into: %{}, do: {expected_player.id, 0})
    }

    {:ok, initial_state}
  end

  @doc """
  When full quorum is reached the match starts immediately.

  If at least two players have joined we start a timeout to begin the match,
  any player joining during that window is added to `joined`. Once the match
  is in any other state, joining players are added to `pending` to be moved
  to `joined` at the start of the next round.
  """
  def add_player(match_id, player_id) do
    GenServer.call(via_tuple(match_id), {:add_player, player_id})
  end

  @doc """
  During `:init` the removal is ignored. If removing the player would leave one
  or fewer players in `joined`, the match is terminated and a `game_finished`
  broadcast is sent. Otherwise the player is simply removed from `joined`.
  """
  def remove_player(match_id, player_id) do
    GenServer.call(via_tuple(match_id), {:remove_player, player_id})
  end

  @doc """
  Broadcasts `round_finished` and starts the answers collection timeout, transitioning
  the game to `:awaiting_answers`.
  """
  def finish_round(match_id) do
    GenServer.call(via_tuple(match_id), :round_finished)
  end

  @doc """
  Stores the player's answers in `player_data`. Once all joined players have answered,
  broadcasts `in_review` for the first category and starts the review timeout.
  """
  def report_player_answers(match_id, player_id, answers) do
    GenServer.call(via_tuple(match_id), {:player_answers, player_id, answers})
  end

  @doc """
  Records the reviewer's verdict for the current category on the target player's
  data. Any non-rejected result is coerced to `:accepted` to create scoring urgency.
  """
  def report_review(match_id, %{reviewer_id: reviewer_id, player_id: player_id, result: result}) do
    GenServer.call(via_tuple(match_id), {:player_review, reviewer_id, player_id, result})
  end

  @doc """
  Returns the full `player_data` map.
  """
  def get_player_data(match_id) do
    GenServer.call(via_tuple(match_id), :get_player_data)
  end

  @doc """
  Returns the current match score for a single player.
  """
  def get_player_score(match_id, player_id) do
    GenServer.call(via_tuple(match_id), {:get_player_score, player_id})
  end

  @doc """
  Returns the full scores map for all players.
  """
  def get_player_scores(match_id) do
    GenServer.call(via_tuple(match_id), :get_player_scores)
  end

  @doc """
  Returns `{:normal, player_data}` during `:init`, or
  `{:ongoing, match_state}` with scores, current category, current letter,
  player data, round number, and game status otherwise. The Match LiveView uses
  this information to discern between active and pending players, thus showing a
  spectator mode for the latter.
  """
  def get_match_state(match_id) do
    GenServer.call(via_tuple(match_id), :get_match_state)
  end

  def handle_call({:add_player, player_id}, _from, %{expected: expected, joined: joined, game_status: game_status} = state) when game_status in [:init, :starting] and length(joined) + 1 == length(expected) do
    all_joined = [player_id|joined]
    scheduler().send_after(self(), :game_start, @game_start_timeout)

    {:reply, :ok, %{state|joined: all_joined, game_status: :ongoing}}
  end

  # Only on the init state we add players to mark them as JOINED
  # In this case we've arrived at at least two players so we start the timeout, if the timeout happens before we have full quorum we're set
  def handle_call({:add_player, player_id}, _from, %{joined: joined, game_status: :init} = state) when length(joined) >= 1 do
    joined = [player_id|joined]

    scheduler().send_after(self(), :game_start, @game_start_timeout)

    {:reply, :ok, %{state|joined: joined, game_status: :starting}}
  end

  def handle_call({:add_player, player_id}, _from, %{joined: joined, game_status: :starting} = state) when length(joined) >= 1 do
    joined = [player_id|joined]

    {:reply, :ok, %{state|joined: joined}}
  end

  # Only on the init state we add players to mark them as JOINED
  def handle_call({:add_player, player_id}, _from, %{joined: joined, game_status: :init} = state) do
    {:reply, :ok, %{state|joined: [player_id|joined]}}
  end

  # On any other game state the player is considered pending and will be moved before the new round starts
  def handle_call({:add_player, player_id}, _from, %{pending: pending} = state) do
    {:reply, :ok, %{state|pending: [player_id|pending]}}
  end

  def handle_call({:remove_player, player_id}, _from, %{game_status: :init} = state), do: {:reply, :ok, state}

  # We're out, there's not enough players and we're not in the initialization phase to be lenient
  def handle_call({:remove_player, player_id}, _from, %{joined: joined} = state) when (length(joined) - 1) <= 1 do
    # Tell the channels to redirect
    broadcast("game_finished", state.match_id, %{})

    {:stop, :no_quorum, state}
  end

  def handle_call({:remove_player, player_id}, _from, state) do
    {:reply, :ok, %{state|joined: state.joined -- [player_id]}}
  end

  def handle_call(:round_finished, _from, state) do
    broadcast("round_finished", state.match_id, %{})

    scheduler().send_after(self(), :answers_timeout, @answers_timeout)
    {:reply, :ok, %{state|game_status: :awaiting_answers}}
  end

  def handle_call({:player_answers, player_id, player_answers}, _from, state) do
    player_data = state.player_data

    updated_player_data =
      Enum.reduce(player_answers, player_data,
        fn {cat, value}, acc ->
          cat_symbol = String.to_existing_atom(cat)
          put_in(acc, [player_id, :answers, cat_symbol, :value], value) end)

    updated_players_answered = [player_id|state.players_answered]

    # If we have gathered the answers of every player that is supposed to be joined
    # we can move on to the :in_review state
    if length(updated_players_answered) == length(state.joined) do
      broadcast("in_review", state.match_id, %{category: Enum.at(@categories, state.cat_index)})

      scheduler().send_after(self(), {:review_timeout, state.cat_index},  @base_review_timeout * length(state.joined))

      {:reply, :ok, %{state|player_data: updated_player_data, game_status: :in_review, players_answered: updated_players_answered}}
    else
      {:reply, :ok, %{state|player_data: updated_player_data, players_answered: updated_players_answered}}
    end
  end

  def handle_call({:player_review, reviewer_id, player_id, result}, _from, %{cat_index: idx} = state) do
    # To create a sense of urgency we set any non-rejected value to accepted, so that the
    # players are motivated to review to not give away free points
    final_result = if result == :rejected, do: result, else: :accepted
    player_data = state.player_data

    updated_player_data =
      put_in(player_data[player_id][:answers][Enum.at(@categories, idx)][:reviews][reviewer_id], final_result)

    # We let the time run out, no ending the review time beforehand. Skipped for now.
    # TODO: End review process earlier if all players have finished voting
    {:reply, {:ok, updated_player_data}, %{state|player_data: updated_player_data}}
  end

  def handle_call(:get_player_data, _from, %{player_data: player_data} = state) do
    {:reply, player_data, state}
  end

  def handle_call({:get_player_score, player_id}, _from, %{score: score} = state) do
    {:reply, score[player_id], state}
  end

  def handle_call(:get_player_scores, _from, %{score: score} = state) do
    {:reply, score, state}
  end

  def handle_call(:get_match_state, _from, %{game_status: :init} = state), do: {:reply, {:normal, state.player_data}, state}

  def handle_call(:get_match_state, _from, %{cat_index: idx, score: score, player_data: player_data, round: round} = state) do
    match_state = %{
      score: state.score,
      current_category: Enum.at(@categories, idx),
      current_letter: state.letter,
      player_data: player_data,
      round_number: round,
      game_status: state.game_status
    }

    {:reply, {:ongoing, match_state}, state}
  end

  def handle_info(:game_start, state) do
    payload = %{
      letter: state.letter,
      round: state.round,
      countdown: @countdown
    }

    broadcast("game_start", state.match_id, payload)

    scheduler().send_after(self(), :round_timeout, @round_timeout)

    {:noreply, %{state|game_status: :ongoing}}
  end

  def handle_info(:no_quorum, %{game_status: :init} = state) do
    {:stop, :no_quorum, state}
  end

  def handle_info(:no_quorum, state) do
    {:noreply, state}
  end

  def handle_info(:round_timeout, %{game_status: :ongoing} = state) do
    broadcast("round_finished", state.match_id, %{})
    {:noreply, %{state|game_status: :awaiting_answers}}
  end

  def handle_info(:round_timeout, state) do
    {:noreply, state}
  end

  def handle_info(:answers_timeout, %{game_status: :awaiting_answers} = state) do
    missing = state.joined -- Map.keys(state.answers)
    updated_joined = state.joined -- missing
    updated_pending = (state.pending ++ missing) |> Enum.uniq()

    scheduler().send_after(self(), {:review_timeout, state.cat_index},  (@base_review_timeout * length(state.joined)))

    {:noreply, %{state | joined: updated_joined, pending: updated_pending, game_status: :in_review}}
  end

  def handle_info(:answers_timeout, state) do
    {:noreply, state}
  end

  # We just start the timeout for the next round
  def handle_info({:review_timeout, cat_idx}, state) when cat_idx >= length(@categories) - 1 do
    round_data_with_scores = Score.scores(state.player_data)
    broadcast("show_scores", state.match_id, %{})

    scheduler().send_after(self(), :show_scores_timeout, @next_round_timeout)

    {:noreply, %{state|game_status: :showing_scores, player_data: round_data_with_scores}}
  end

  def handle_info({:review_timeout, cat_idx}, state) do
    new_cat_index = cat_idx + 1

    broadcast("in_review", state.match_id, %{category: Enum.at(@categories, new_cat_index)})
    scheduler().send_after(self(), {:review_timeout, new_cat_index},  @base_review_timeout * length(state.joined))

    {:noreply, %{state | cat_index: new_cat_index}}
  end

  def handle_info(:show_scores_timeout, state) do
    # 2. Start next round timeout
    broadcast("next_round", state.match_id, %{timeout: @next_round_timeout / 1_000})
    scheduler().send_after(self(), :next_round_timeout, @next_round_timeout)

    player_data = Score.default_player_data(state.expected)
    updated_score = update_match_score(state.player_data, state.score)

    {:noreply, %{state|game_status: :next_round, player_data: player_data, score: updated_score}}
  end

  # Timeout for next round has finished so we start the round
  def handle_info(:next_round_timeout, state) do
    {new_letter, new_alphabet} = pick_letter_from(state.alphabet)
    new_round = state.round + 1

    payload = %{
      letter: new_letter,
      round: new_round,
      countdown: @countdown
    }

    broadcast("round_start", state.match_id, payload)

    scheduler().send_after(self(), :round_timeout, @round_timeout)

    {:noreply,
     %{state|
       game_status: :ongoing,
       alphabet: new_alphabet,
       round: new_round,
       letter: new_letter,
       cat_index: 0,
       players_answered: [],
     }
    }
  end

  defp make_alphabet() do
    Enum.map(65..90, &<<&1::utf8>>)
  end

  defp pick_letter_from(alphabet) do
    letter = Enum.random(alphabet)
    {letter, List.delete(alphabet, letter)}
  end

  defp via_tuple(match_id) do
    {:via, Registry, {StopMyHand.Registry, match_id}}
  end

  defp broadcast(event, match_id, payload) do
    Endpoint.broadcast!("#{@match_topic}:#{match_id}", event, payload)
  end

  defp update_match_score(player_data, current_match_score) do
    for {player_id, data} <- player_data, reduce: current_match_score do
      current_scores ->
        round_score = Enum.reduce(data.answers, 0, fn {_cat, answer}, sum -> sum + answer.result.points end)
        put_in(current_scores[player_id], current_scores[player_id] + round_score)
    end
  end

  defp scheduler do
    Application.get_env(:stop_my_hand, :scheduler)
  end
end
