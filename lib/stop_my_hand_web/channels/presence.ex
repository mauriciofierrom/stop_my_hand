defmodule StopMyHandWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  We track the online status of the users and broadcast each individual changes
  from their frineds to their own dedicated firends:<user_id> channel.
  """
  use Phoenix.Presence,
    otp_app: :stop_my_hand,
    pubsub_server: StopMyHand.PubSub

  alias StopMyHand.Cache
  alias StopMyHandWeb.Endpoint

  @online "online_users"
  @friends "friends:"

  @spec init(any()) :: {:ok, %{}}
  def init(_opts) do
    {:ok, %{}}
  end

  def handle_metas(_topic, %{joins: joins, leaves: leaves}, _presences, state) do
    for {target_user_id, _presence} <- joins do
      {user_id, _} = Integer.parse(target_user_id)
      msg = {__MODULE__, {:join, user_id}}

      Cache.get_friend_id_list(user_id)
      |> Enum.each(fn {friend_id, _status} -> Endpoint.broadcast("friends:#{friend_id}", "join", msg) end)
    end

    for {target_user_id, _presence} <- leaves do
      {user_id, _} = Integer.parse(target_user_id)
      msg = {__MODULE__, {:leave, user_id}}

      Cache.get_friend_id_list(user_id)
      |> Enum.each(fn {friend_id, _status} -> Endpoint.broadcast("friends:#{friend_id}", "leave", msg) end)
    end

    {:ok, state}
  end

  def get_status(user_id) do
    if match?(%{}, get_by_key(@online, user_id)), do: :online, else: :offline
  end

  def subscribe_friends_updates(user_id) do
    Endpoint.subscribe("#{@friends}#{user_id}")
  end
end
