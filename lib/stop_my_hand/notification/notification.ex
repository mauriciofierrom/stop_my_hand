defmodule StopMyHand.Notification.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :title, :string
    field :status, :string
    field :type, :string
    field :user_id, :id
    field :metadata, :map

    timestamps()
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:title, :status, :type, :metadata, :user_id, :inserted_at, :updated_at])
    |> validate_required([:title, :status, :type, :metadata, :user_id])
  end

  def mark_read_changeset(notification, attrs) do
    notification
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, ["unread", "read"])
  end
end
