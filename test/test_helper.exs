Application.ensure_all_started(:mox)
Mox.defmock(StopMyHand.Scheduler.Mock, for: StopMyHand.Scheduler)
Application.put_env(:stop_my_hand, :scheduler, StopMyHand.Scheduler.Mock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(StopMyHand.Repo, :manual)
