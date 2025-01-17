defmodule StopMyHand.Game.Match do
  use Ecto.Schema
  import Ecto.Changeset
  alias StopMyHand.Game.Player

  schema "matches" do

    field :creator_id, :id

    has_many :players, Player, foreign_key: :match_id

    timestamps()
  end

  @doc false
  def changeset(match, attrs) do
    match
    |> cast(attrs, [:creator_id])
    |> cast_assoc(:players)
    |> validate_required([:creator_id])
  end
end
