defmodule StopMyHandWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  We track the online status of the users and broadcast each individual changes
  from their friends to their own dedicated `friends:<user_id>` channel.
  """
  use Phoenix.Presence,
    otp_app: :stop_my_hand,
    pubsub_server: StopMyHand.PubSub

  alias StopMyHand.Cache
  alias StopMyHandWeb.Endpoint

  @online "online_users"
  @friends_topic "friends"
  @match_changes_topic "match_changes"
  @join "join"
  @leave "leave"

  def init(_opts) do
    {:ok, %{}}
  end

  @doc """
  The metas to keep presence of are as follows:

  - `online_users` - Used to keep track of online users. A user qualifies as online if they're in the Main page only.
  - `match:<match_id>` - Used to determine if a user has arrived at a Match Lobby, that is, if the user is ready to be in a match
  """
  def handle_metas(@online, %{joins: joins, leaves: leaves}, _presences, state) do
    for {target_user_id, _presence} <- joins do
      user_id = String.to_integer(target_user_id)
      msg = {__MODULE__, {:join, user_id}}

      Cache.get_friend_id_list(user_id)
      |> Enum.each(fn {friend_id, _status} ->
        Endpoint.broadcast("#{@friends_topic}:#{friend_id}", @join, msg) end)
    end

    for {target_user_id, _presence} <- leaves do
      user_id = String.to_integer(target_user_id)
      msg = {__MODULE__, {:leave, user_id}}

      Cache.get_friend_id_list(user_id)
      |> Enum.each(fn {friend_id, _status} ->
        Endpoint.broadcast("#{@friends_topic}:#{friend_id}", @leave, msg) end)
    end

    {:ok, state}
  end

  def handle_metas("match:" <> match_id, %{joins: joins, leaves: leaves}, _presences, state) do
    for {target_user_id, _presence} <- joins do
      user_id = String.to_integer(target_user_id)
      msg = {__MODULE__, {:join, user_id}}

      Endpoint.broadcast("#{@match_changes_topic}:#{match_id}", @join, msg)
    end

    for {target_user_id, _presence} <- leaves do
      user_id = String.to_integer(target_user_id)
      msg = {__MODULE__, {:leave, user_id}}

      Endpoint.broadcast("#{@match_changes_topic}:#{match_id}", @leave, msg)
    end

    {:ok, state}
  end

  @doc """
  Determine if the user is `online`
  """
  def get_status(user_id) do
    if match?(%{}, get_by_key(@online, user_id)), do: :online, else: :offline
  end

  @doc """
  Helper to subscribe to a friend's update
  """
  def subscribe_friends_updates(user_id) do
    Endpoint.subscribe("#{@friends_topic}:#{user_id}")
  end
end
