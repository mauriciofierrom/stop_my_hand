defmodule StopMyHand.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :title, :string
      add :type, :string
      add :status, :string
      add :user_id, references(:users, on_delete: :nothing)
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:notifications, [:user_id])
  end
end
