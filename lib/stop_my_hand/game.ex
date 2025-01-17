defmodule StopMyHand.Game do
  @moduledoc """
  The Game context.
  """
  @notification "notification"

  import Ecto.Query, warn: false

  alias StopMyHand.Repo
  alias StopMyHandWeb.Endpoint
  alias StopMyHand.Game.{Match}

  def create_match(current_user, attrs) do
    case insert_match(attrs) do
      {:ok, match} ->
        notify_players(current_user.username, match)
        {:ok, match}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp insert_match(attrs) do
    %Match{}
    |> Match.changeset(attrs)
    |> Repo.insert()
  end

  defp notify_players(invitee_handle, match) do
    Enum.each(match.players, fn player ->
      Endpoint.broadcast("#{@notification}:#{player.user_id}",
        "game_invite",
        %{game_id: match.id, invitee_handle: invitee_handle}
      )
    end)
  end
end
