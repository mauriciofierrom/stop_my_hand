defmodule StopMyHand.MatchDriver do
  @moduledoc """
  A GenServer to drive the match and its rounds
  """
  use GenServer

  def start_link(%{player_ids: player_ids, match_id: match_id}) do
    GenServer.start_link(__MODULE__, player_ids, name: via_tuple(match_id))
  end

  def init(expected_player_ids) do
    initial_state = %{
      expected: expected_player_ids,
      alphabet: make_alphabet(),
      joined: []
    }
    {:ok, initial_state}
  end

  def player_joined(match_id, player_id) do
    GenServer.call(via_tuple(match_id), {:add_player, player_id})
  end

  def pick_letter(match_id) do
    GenServer.call(via_tuple(match_id), :pick_letter)
  end

  def all_players_in?(match_id) do
    GenServer.call(via_tuple(match_id), :check_all_players_in)
  end


  def handle_call({:add_player, player_id}, _from, %{joined: joined} = state) do
    {:reply, :ok, %{state|joined: [player_id|joined]}}
  end

  def handle_call(:pick_letter, _from, %{alphabet: alphabet} = state) do
    letter = Enum.random(alphabet)
    if Enum.empty?(alphabet) do
      {:reply, {:error, "No more letters"}, state}
    else
      {:reply, {:ok, letter}, %{state|alphabet: List.delete(alphabet, letter)}}
    end
  end

  def handle_call(:check_all_players_in, _from, %{expected: expected, joined: joined} = state) do
    {:reply, Enum.all?(joined, &(Enum.member?(expected, &1))), state}
  end

  defp via_tuple(match_id) do
    {:via, Registry, {StopMyHand.Registry, match_id}}
  end

  defp make_alphabet() do
    Enum.map(65..90, &<<&1::utf8>>)
  end
end
