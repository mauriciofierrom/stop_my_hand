defmodule StopMyHand.Friendship.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  schema "friendship" do

    field :this_id, :id
    field :that_id, :id
    field :invite_id, :id

    timestamps()
  end

  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:this_id, :that_id, :invite_id])
    |> check_constraint(:this_id, name: :this_and_that_different)
    |> unique_constraint([:this_id, :that_id])
  end
end
