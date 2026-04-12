defmodule StopMyHand.SecureMetricsEndpoint do
  @behaviour Unplug.Predicate

  @impl true
  def call(conn, env_var) do
    auth_header = Plug.Conn.get_req_header(conn, "authorization")

    List.first(auth_header) == "Bearer #{System.get_env(env_var)}"
  end
end
