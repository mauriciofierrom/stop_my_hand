defmodule StopMyHand.Game do
  @moduledoc """
  The Game context.
  """
  @notification "notification"

  import Ecto.Query, warn: false

  alias StopMyHand.Repo
  alias StopMyHandWeb.Endpoint
  alias StopMyHand.Game.{Match, Player}
  alias StopMyHand.Notification

  def create_match(current_user, attrs) do
    case Repo.transact(fn ->
      with {:ok, match} <- insert_match(attrs),
          {:ok, notifications} <- Notification.notify_players(current_user.username, match) do
        {:ok, {match, notifications}}
      end
    end) do
      {:ok, {match, notifications}} ->
        Notification.broadcast_notifications(notifications)
        {:ok, match}
      error -> error
    end
  end

  def get_match_players(match_id) do
    (from p in Player,
    where: p.match_id == ^match_id,
    select: p) |> Repo.all |> Repo.preload(:user)
  end

  def get_match(match_id) do
    Repo.get!(Match, match_id) |> Repo.preload([:creator, players: [:user]])
  end

  def get_creator_player(match) do
    IO.inspect(match, label: "match")
    Repo.get_by(Player, match_id: match.id, user_id: match.creator_id)
  end

  defp insert_match(attrs) do
    %Match{}
    |> Match.changeset(attrs)
    |> Repo.insert()
  end
end
