defmodule StopMyHand.FriendshipTest do
  use StopMyHand.DataCase

  alias StopMyHand.Friendship

  import StopMyHand.FriendshipFixtures
  import StopMyHand.AccountsFixtures

  alias StopMyHand.Accounts.{User}
  alias StopMyHand.Friendship.{Invite}

  describe "send_invite/2" do
    test "it sents the invite from the first user to the second" do
      %User{id: invitee_id} = user_fixture()
      %User{id: invited_id} = user_fixture()

      {:ok, %Invite{state: state}} = Friendship.send_invite(%Invite{}, %{invitee_id: invitee_id, invited_id: invited_id})

      assert state == :pending
    end

    test "it fails if the same user is used as both invited and invitee" do
      %User{id: id} = user_fixture()

      assert {:error, _} = Friendship.send_invite(%Invite{}, %{invited_id: id, invitee_id: id})
    end

    test "fails if there's already an existing invitation" do
      %User{id: invitee_id} = user_fixture()
      %User{id: invited_id} = user_fixture()

      Friendship.send_invite(%Invite{}, %{invitee_id: invitee_id, invited_id: invited_id})

      assert {:error, _} = Friendship.send_invite(%Invite{}, %{invited_id: invited_id, invitee_id: invitee_id})
    end

    test "fails when re-inviting in less than 24 hours since last invite" do
      %User{id: invitee_id} = user_fixture()
      %User{id: invited_id} = user_fixture()

      {:ok, invite} = Friendship.send_invite(%Invite{}, %{invitee_id: invitee_id, invited_id: invited_id})

      assert {:error, _} = Friendship.send_invite(invite, %{state: :pending})
    end

    test "succeeds when re-inviting later than 24 hours since last invite" do
      %Invite{invitee_id: invitee_id, invited_id: invited_id} = two_day_invite = two_day_invite()

      {:ok, %Invite{state: state}} = Friendship.send_invite(two_day_invite, %{invitee_id: invitee_id, invited_id: invited_id})

      assert state == :pending
    end
  end

  describe "reject_invite/1" do
    test "it marks the invitaiton as rejected" do
      assert {:ok, %Invite{state: :rejected}} = rejected_invite()
    end
  end

  describe "accept_invite/1" do
    test "it marks the invite as accepted" do
      assert {:ok, %{invite: %Invite{state: :accepted}}} = accepted_invite()
    end

    @tag focus: true
    test "it creates a friendship record with the related invite" do
      {:ok, %{invite: invite, friendship: friendship}} = accepted_invite()

      assert friendship.this_id == invite.invitee_id
      assert friendship.that_id == invite.invited_id
      assert friendship.invite_id == invite.id
    end
  end

  describe "get_pending_invites/1" do
    test "does not return anything if there aren't pending sent invites" do
      %User{id: id} = user_fixture()
      refute Friendship.get_pending_invites(id)
    end

    test "returns only pending sent invites" do
      {:ok, %{invite: %Invite{invitee_id: id}}} = accepted_invite()
      {:ok, %Invite{invitee_id: other_id}} = rejected_invite()
      {:ok, %Invite{invitee_id: pending_id}} = invite_fixture()


      refute Friendship.get_pending_invites(id)
      refute Friendship.get_pending_invites(other_id)
      assert Friendship.get_pending_invites(pending_id)
    end
  end

  describe "delete_friend/2" do
    test "it deletes the friendship record" do
      {:ok, %{friendship: friendship}} = accepted_invite()

      assert {:ok, _} = Friendship.remove_friend(friendship)
    end
  end
end
