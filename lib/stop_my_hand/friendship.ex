defmodule StopMyHand.Friendship do
  @moduledoc """
  The Friendship context.
  """

  import Ecto.Query, warn: false
  alias StopMyHand.Repo
  alias StopMyHand.Accounts.User
  alias Ecto.Multi

  alias StopMyHand.Friendship.{Invite, Friendship}

  def send_invite(attrs) do
    %Invite{}
    |> Invite.sending_changeset(attrs)
    |> Repo.insert(on_conflict: {:replace, [:state]}, conflict_target: [:invited_id, :invitee_id])
  end

  def get_invite_with_invitee(invite_id) do
    Repo.get!(Invite, invite_id) |> Repo.preload(:invitee)
  end

  def get_pending_invites(user_id) do
    query = from i in Invite,
            where: i.invited_id == ^user_id and i.state == :pending
    Repo.all(query) |> Repo.preload(:invitee)
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

  def remove_friend(current_user, user_id) do
    friendship_query = from f in Friendship,
                       where: f.this_id == ^current_user.id and f.that_id == ^user_id or
                                f.that_id == ^current_user.id and f.this_id == ^user_id
    friendship = Repo.one!(friendship_query)

    query = from i in Invite,
            where: i.invited_id == ^friendship.this_id and i.invitee_id == ^friendship.that_id or
                     i.invited_id == ^friendship.that_id and i.invitee_id == ^friendship.this_id,
            where: i.state == :accepted

    Multi.new()
    |> Multi.delete_all(:delete_invite, query)
    |> Multi.delete(:delete_friendship, friendship)
    |> Repo.transaction()
  end

  def search_invitable_users(username, current_user) do
    from(u in User,
    as: :user,
    where: not exists(
      from(f in Friendship,
           where: f.this_id == parent_as(:user).id or f.that_id == parent_as(:user).id,
           select: 1
      )
    ),
    where: not exists(
      from(i in Invite,
           where: i.invitee_id == parent_as(:user).id or i.invited_id == parent_as(:user).id,
           select: 1
      )
    ),
    where: ilike(u.username, ^"#{username}%") and u.id != ^current_user.id)
    |> Repo.all
  end

  def get_friends(user_id) do
    query = from f in Friendship,
              join: u in User, on: u.id == f.this_id or u.id == f.that_id,
              where: u.id != ^user_id,
              select: u
    Repo.all(query)
  end
end
