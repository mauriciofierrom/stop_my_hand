defmodule StopMyHand.Friendship do
  @moduledoc """
  The Friendship context.
  """

  import Ecto.Query, warn: false
  alias StopMyHand.Repo
  alias Ecto.Multi

  alias StopMyHand.Friendship.{Invite, Friendship}

  def send_invite(invite, attrs) do
    invite
    |> Invite.sending_changeset(attrs)
    |> Repo.insert(on_conflict: {:replace, [:state]}, conflict_target: :id)
  end

  def get_pending_invites(user_id) do
    Repo.get_by(Invite, invitee_id: user_id, state: :pending)
  end

  def accept_invite(%Invite{id: id, invitee_id: this_id, invited_id: that_id} = invite) do
    Multi.new()
    |> Multi.update(:invite, Invite.state_changeset(invite, %{state: :accepted}))
    |> Multi.insert(:friendship, Friendship.changeset(%Friendship{}, %{this_id: this_id, that_id: that_id, invite_id: id}))
    |> Repo.transaction()
  end

  def reject_invite(invite) do
    invite
    |> Invite.state_changeset(%{state: :rejected})
    |> Repo.update()
  end

  def remove_friend(friendship) do
    friendship
    |> Repo.delete()
  end
end
