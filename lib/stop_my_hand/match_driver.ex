defmodule StopMyHand.MatchDriver do
  @moduledoc """
  A GenServer to drive the match and its rounds
  """
  use GenServer

  alias StopMyHandWeb.Endpoint

  @quorum_timeout 15_000
  @game_start_timeout 1_000
  @answers_timeout 10_000
  @review_timeout 10_000
  @next_round_timeout 5_000
  @match_topic "match"
  @countdown 3
  @round_timeout (@countdown * 1_000) + 180_000
  @categories [:name, :last_name, :city, :color, :animal, :thing]

  def start_link(%{player_ids: player_ids, match_id: match_id}) do
    GenServer.start_link(__MODULE__, {player_ids, match_id}, name: via_tuple(match_id))
  end

  def init({expected_player_ids, match_id}) do
    {starting_letter, alphabet} = pick_letter_from(make_alphabet())

    Process.send_after(self(), :no_quorum, @quorum_timeout)

    initial_state = %{
      match_id: match_id,
      alphabet: alphabet,
      round: 1,
      letter: starting_letter,
      expected: expected_player_ids,
      joined: [],
      pending: [],
      game_status: :init,
      answers: %{},
      cat_index: 0,
      reviews: %{}
    }

    {:ok, initial_state}
  end

  def player_joined(match_id, player_id) do
    GenServer.call(via_tuple(match_id), {:add_player, player_id})
  end

  def pick_letter(match_id) do
    GenServer.call(via_tuple(match_id), :pick_letter)
  end

  def round_finished(match_id) do
    GenServer.call(via_tuple(match_id), :round_finished)
  end

  def player_answers(match_id, player_id, answers) do
    GenServer.call(via_tuple(match_id), {:player_answers, player_id, answers})
  end

  def report_review(match_id, %{reviewer_id: reviewer_id, player_id: player_id, result: result}) do
    GenServer.call(via_tuple(match_id), {:player_review, reviewer_id, player_id, result})
  end

  def handle_call({:add_player, player_id}, _from, %{expected: expected, joined: joined, game_status: :init} = state) when length(joined) == length(expected) do
    # Set the status to started when there's quorum
    new_status = if length(joined) >= 1, do: :ongoing, else: state.game_status

    Process.send_after(self(), :game_start, @game_start_timeout)

    {:noreply, %{state|joined: [player_id|joined], game_status: :ongoing}}
  end

  # Only on the init state we add players to mark them as JOINED
  def handle_call({:add_player, player_id}, _from, %{joined: joined, game_status: :init} = state) when length(joined) >= 1 do
    Process.send_after(self(), :game_start, @game_start_timeout)

    {:reply, %{ok: :pending}, %{state|joined: [player_id|joined], game_status: :ongoing}}
  end

  # Only on the init state we add players to mark them as JOINED
  def handle_call({:add_player, player_id}, _from, %{joined: joined, game_status: :init} = state) do
    {:reply, %{ok: :pending}, %{state|joined: [player_id|joined]}}
  end

  # On any other game state the player is considered pending and will be moved before the new round starts
  def handle_call({:add_player, player_id}, _from, %{pending: pending} = state) do
    {:reply, :ok, %{state|pending: [player_id|pending]}}
  end

  def handle_call(:pick_letter, _from, %{alphabet: []} = state), do: {:reply, {:error, "No more letters"}, state}

  def handle_call(:pick_letter, _from, %{alphabet: alphabet} = state) do
    {letter, new_alphabet} = pick_letter_from(alphabet)
    {:reply, {:ok, letter}, %{state|alphabet: new_alphabet}}
  end

  def handle_call(:round_finished, _from, state) do
    broadcast("round_finished", state.match_id, %{})

    Process.send_after(self(), :answers_timeout, @answers_timeout)
    {:reply, :ok, %{state|game_status: :awaiting_answers}}
  end

  def handle_call({:player_answers, player_id, player_answers}, _from, state) do
    updated_answers = Map.put(state.answers, player_id, player_answers)

    # If we have gathered the answers of every player that is supposed to be joined
    # we can move on to the :in_review state
    if length(Map.keys(updated_answers)) == length(state.joined) do
      broadcast("in_review", state.match_id, %{category: Enum.at(@categories, state.cat_index), answers: updated_answers})

      Process.send_after(self(), {:review_timeout, state.cat_index},  @review_timeout)

      {:reply, :ok, %{state|answers: updated_answers, game_status: :in_review, reviews: default_reviews(state.joined)}}
    else
      {:reply, :ok, %{state|answers: updated_answers}}
    end
  end

  def handle_call({:player_review, reviewer_id, player_id, result}, _from, %{reviews: reviews, cat_index: idx} = state) do
    # We let the time run out, no ending the review time beforehand. Skipped for now.
    # TODO: End review process earlier if all players have finished voting
    {:reply, :ok, %{state|reviews: put_in(reviews[reviewer_id][Enum.at(@categories, idx)][player_id], result)}}
  end

  def handle_info(:game_start, state) do
    payload = %{
      letter: state.letter,
      round: state.round,
      countdown: @countdown
    }

    broadcast("game_start", state.match_id, payload)

    Process.send_after(self(), :round_timeout, @round_timeout)

    {:noreply, state}
  end

  def handle_info(:no_quorum, %{game_status: :init} = state) do
    GenServer.stop(self(), :no_quorum, 5000)
  end

  def handle_info(:no_quorum, state) do
    {:noreply, state}
  end

  def handle_info(:round_timeout, %{game_status: :ongoing} = state) do
    broadcast("round_finished", state.match_id, %{})
    {:noreply, %{state|game_status: :awaiting_answers}}
  end

  def handle_info(:round_timeout, state) do
    IO.inspect("Round timeout not reached")
    {:noreply, state}
  end

  def handle_info(:answers_timeout, %{game_status: :awaiting_answers} = state) do
    missing = state.joined -- Map.keys(state.answers)
    updated_joined = state.joined -- missing
    updated_pending = (state.pending ++ missing) |> Enum.uniq()

    {:noreply, %{state | joined: updated_joined, pending: updated_pending, game_status: :in_review, reviews: default_reviews(updated_joined)}}
  end

  def handle_info(:answers_timeout, state), do: {:noreply, state}

  # We just start the timeout for the next round
  def handle_info({:review_timeout, cat_idx}, state) when cat_idx >= length(@categories) - 1 do
    IO.inspect(cat_idx, label: "The index when it's supposed to end")
    # 1. Update scores
    # 2. Start next round timeout
    Process.send_after(self(), :next_round_timeout, @next_round_timeout)

    {:noreply, %{state|game_status: :next_round, cat_index: 0}}
  end

  # TODO: When we skip early when all reviews are in we need to discriminate here on the current index
  def handle_info({:review_timeout, cat_idx}, state) do
    new_cat_index = cat_idx + 1
    IO.inspect(new_cat_index, label: "New cat index")

    broadcast("in_review", state.match_id, %{category: Enum.at(@categories, new_cat_index), answers: state.answers})
    Process.send_after(self(), {:review_timeout, new_cat_index},  @review_timeout)

    {:noreply, %{state | cat_index: new_cat_index}}
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

    broadcast("game_start", state.match_id, payload)

    Process.send_after(self(), :round_timeout, @round_timeout)

    {:noreply,
     %{state|
       game_status: :ongoing,
       alphabet: new_alphabet,
       round: new_round,
       letter: new_letter,
       reviews: default_reviews(state.joined),
       answers: %{}
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

  # %{player_id: %{cat: %{reviewer_id: result}}}
  def default_reviews(player_ids) do
    Map.new(player_ids, fn player_id ->
      {player_id, Map.new(@categories, fn cat -> {cat, Map.new(player_ids -- [player_id], &{&1, :none})} end)}
    end)
  end
end
