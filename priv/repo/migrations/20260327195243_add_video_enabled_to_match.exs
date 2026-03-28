defmodule StopMyHand.Repo.Migrations.AddVideoEnabledToMatch do
  use Ecto.Migration

  def change do
    alter table("matches") do
      add :video_enabled, :boolean, default: false, null: false
    end

    create index("matches", [:video_enabled], where: "video_enabled = true", name: :video_enabled_idx)
  end
end
