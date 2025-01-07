defmodule StopMyHand.Cache do
  @moduledoc """
  A GenServer to handle the presence cache
  """
  use GenServer

  alias :ets, as: ETS

  @list :friendlist

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    ETS.new(@list, [:ordered_set, :named_table])

    {:ok, :ok}
  end

  def load_online_friend_list(params) do
    GenServer.call(__MODULE__, {:load_online_list, params})
  end

  def update_online_friendlist(changes) do
    GenServer.call(__MODULE__, {:update_list, changes})
  end

  def get_friend_id_list(user_id) do
    GenServer.call(__MODULE__, {:get_list, user_id})
  end

  def handle_call({:get_list, user_id}, _from, _state) do
    l = ETS.lookup(@list, user_id)
    case l do
      [] -> {:reply, [], :ok}
      list -> {:reply, list |> List.first |> elem(1), :ok}
    end
  end

  def handle_call({:load_online_list, %{user_id: user_id, list: list}}, _from, _state) do
    if ETS.insert(@list, {user_id, list}) do
      {:reply, :ok, :ok}
    else
      {:reply, :error, :ok}
    end
  end
end
