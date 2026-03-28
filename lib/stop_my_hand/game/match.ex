defmodule StopMyHand.Game.Match do
  use Ecto.Schema
  import Ecto.Changeset
  alias StopMyHand.Game.Player
  alias StopMyHand.Accounts.User

  schema "matches" do
    field :video_enabled, :boolean

    belongs_to :creator, User
    has_many :players, Player, foreign_key: :match_id

    timestamps()
  end

  @doc false
  def changeset(match, attrs) do
    match
    |> cast(attrs, [:creator_id, :video_enabled])
    |> cast_assoc(:players)
    |> validate_required([:creator_id])
  end
end
