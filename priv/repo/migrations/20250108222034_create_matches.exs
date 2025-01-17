defmodule StopMyHand.Repo.Migrations.CreateMatches do
  use Ecto.Migration

  def change do
    create table(:matches) do
      add :creator_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:matches, [:creator_id])
  end
end
