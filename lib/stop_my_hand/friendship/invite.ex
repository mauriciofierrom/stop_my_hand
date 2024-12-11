defmodule StopMyHand.Friendship.Invite do
  use Ecto.Schema
  import Ecto.Changeset

  alias StopMyHand.Accounts.{User}

  schema "invite" do
    field :state, Ecto.Enum, values: [:pending, :accepted, :rejected]
    belongs_to :invitee, User
    belongs_to :invited, User

    timestamps()
  end

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:state])
    |> validate_required([:state])
  end

  def sending_changeset(invite, attrs) do
    invite
    |> cast(Enum.into(attrs, %{state: :pending}), [:invitee_id, :invited_id, :state])
    |> validate_invite_timeframe()
    |> check_constraint(:invitee_id, name: :invitee_and_invited_different)
    |> unique_constraint([:invitee_id, :invited_id])
  end

  def state_changeset(invite, attrs) do
    invite
    |> cast(attrs, [:state])
    |> unique_constraint([:invitee_id, :invited_id])
  end

  def frienship_changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:this_id, :that_id, :invite_id])
    |> check_constraint(:this_id, name: :this_and_that_different)
    |> unique_constraint([:this_id, :that_id])
  end

  # either there's no invite or the last invite state
  # is ignored and the last_modified is greater than a
  # prudent value (24h for starters)
  defp validate_invite_timeframe(changeset) do
    case changeset.data.updated_at do
      nil -> changeset
      updated_at ->
        now = DateTime.utc_now
        # TODO: This requires timezone handling
        diff = DateTime.diff(now, DateTime.from_naive!(updated_at, "Etc/UTC"), :hour)
        if diff >= 24 do
          changeset
        else
          add_error(changeset, "inviting again too soon", "Only one invitation per 24 hours can be sent")
        end
    end
  end
end
