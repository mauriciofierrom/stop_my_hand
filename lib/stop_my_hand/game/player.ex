defmodule StopMyHand.Game.Player do
  use Ecto.Schema
  import Ecto.Changeset

  alias StopMyHand.Accounts.{User}

  schema "players" do
    field :match_id, :id
    belongs_to :user, User
    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:match_id, :user_id])
    |> validate_required([:user_id])
  end
end
