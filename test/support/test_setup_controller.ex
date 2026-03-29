defmodule StopMyHandWeb.TestSetupController do
  use StopMyHandWeb, :controller
  alias StopMyHand.Accounts
  alias StopMyHandWeb.UserAuth

  def setup(conn, %{"scenario" => scenario}) do
    ids = StopMyHand.TestScenarios.run(scenario)
    json(conn, ids)
  end

  def login(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)
    token = Accounts.generate_user_session_token(user)
    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
    |> send_resp(200, "")
  end
end
