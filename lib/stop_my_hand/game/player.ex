defmodule StopMyHand.Game.Player do
  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do

    field :match_id, :id
    field :user_id, :id

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:match_id, :user_id])
    |> validate_required([:user_id])
  end
end
