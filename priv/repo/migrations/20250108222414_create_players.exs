defmodule StopMyHand.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :match_id, references(:matches, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:players, [:match_id])
    create index(:players, [:user_id])
  end
end
