defmodule StopMyHand.MatchDriver do
  @moduledoc """
  A GenServer to drive the match and its rounds
  """
  use GenServer

  alias StopMyHandWeb.Endpoint

  @quorum_timeout 15000
  @match_topic "match"
  @countdown 3

  def start_link(%{player_ids: player_ids, match_id: match_id}) do
    GenServer.start_link(__MODULE__, {player_ids, match_id}, name: via_tuple(match_id))
  end

  def init({ expected_player_ids, match_id}) do
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
    }

    {:ok, initial_state}
  end

  def player_joined(match_id, player_id) do
    GenServer.call(via_tuple(match_id), {:add_player, player_id})
  end

  def pick_letter(match_id) do
    GenServer.call(via_tuple(match_id), :pick_letter)
  end

  def handle_call({:add_player, player_id}, _from, %{expected: expected, joined: joined, game_status: :init} = state) when length(joined) == length(expected) do
    # Set the status to started when there's quorum
    new_status = if length(joined) >= 1, do: :ongoing, else: state.game_status

    Process.send_after(self(), :game_start, 1000)

    {:noreply, %{state|joined: [player_id|joined], game_status: :ongoing}}
  end

  # Only on the init state we add players to mark them as JOINED
  def handle_call({:add_player, player_id}, _from, %{joined: joined, game_status: :init} = state) when length(joined) >= 1 do
    Process.send_after(self(), :game_start, 200)

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

  def handle_info(:game_start, state) do
    payload = %{
      letter: state.letter,
      round: state.round,
      countdown: @countdown
    }

    Endpoint.broadcast!("#{@match_topic}:#{state.match_id}", "game_start", payload)
  end

  def handle_info(:no_quorum, %{game_status: :init} = state) do
    GenServer.stop(self(), :no_quorum, 5000)
  end

  def handle_info(:no_quorum, state) do
    {:noreply, state}
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
end
