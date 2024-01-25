defmodule StopMyHand.Repo do
  use Ecto.Repo,
    otp_app: :stop_my_hand,
    adapter: Ecto.Adapters.Postgres
end
