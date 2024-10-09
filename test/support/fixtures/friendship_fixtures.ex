defmodule StopMyHand.FriendshipFixtures do
  use StopMyHand.DataCase

  alias StopMyHand.Friendship

  alias StopMyHand.Accounts.{User}
  import StopMyHand.AccountsFixtures
  alias StopMyHand.Repo

  def invite_fixture() do
    %User{id: invitee_id} = user_fixture()
    %User{id: invited_id} = user_fixture()

    {:ok, invite} = Friendship.send_invite(%{invitee_id: invitee_id, invited_id: invited_id})
    Repo.preload(invite, :invitee)
  end

  def invite_fixture(invited_id) do
    %User{id: invitee_id} = user_fixture()
    {:ok, invite} = Friendship.send_invite(%{invitee_id: invitee_id, invited_id: invited_id})
    Repo.preload(invite, :invitee)
  end

  def two_day_invite() do
    %User{id: invitee_id} = user_fixture()
    %User{id: invited_id} = user_fixture()

    {:ok, invite} = Friendship.send_invite(%{invitee_id: invitee_id, invited_id: invited_id})

    two_days_ago = DateTime.from_naive!(DateTime.utc_now, "Etc/UTC")
    |> DateTime.add(-2, :day)
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)

    Repo.update!(Ecto.Changeset.change(invite, updated_at: two_days_ago, state: :rejected))
  end

  def accepted_invite() do
    %User{id: invitee_id} = user_fixture()
    %User{id: invited_id} = user_fixture()

    {:ok, invite} = Friendship.send_invite(%{invitee_id: invitee_id, invited_id: invited_id})

    Friendship.accept_invite(invite)
  end

  def rejected_invite() do
    %User{id: invitee_id} = user_fixture()
    %User{id: invited_id} = user_fixture()

    {:ok, invite} = Friendship.send_invite(%{invitee_id: invitee_id, invited_id: invited_id})

    Friendship.reject_invite(invite)
  end
end
