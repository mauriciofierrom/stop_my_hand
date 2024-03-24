defmodule StopMyHand.Repo.Migrations.CreateFriendship do
  use Ecto.Migration

  def change do
    create table(:friendship) do
      add :this_id, references(:users, on_delete: :delete_all)
      add :that_id, references(:users, on_delete: :delete_all)
      add :invite_id, references(:invite, on_delete: :nilify_all)

      timestamps()
    end

    create index(:friendship, [:this_id])
    create index(:friendship, [:that_id])
    create index(:friendship, [:invite_id])

    create constraint(:friendship, :this_and_that_different, check: "this_id <> that_id")
  end
end
