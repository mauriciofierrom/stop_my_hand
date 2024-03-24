defmodule StopMyHand.Repo.Migrations.CreateInvite do
  use Ecto.Migration

  def change do
    create table(:invite) do
      add :state, :string
      add :invitee_id, references(:users, on_delete: :delete_all)
      add :invited_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:invite, [:invitee_id])
    create index(:invite, [:invited_id])

    create constraint(:invite, :invitee_and_invited_different, check: "invitee_id <> invited_id")
    create unique_index(:invite, [:invitee_id, :invited_id])
  end
end
