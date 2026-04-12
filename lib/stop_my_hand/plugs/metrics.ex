defmodule StopMyHand.Plugs.Metrics do
  import Plug.Conn

  def init(opts), do: opts

  def call(%{request_path: "/metrics"} = conn, _opts) do
    expected = "Bearer #{System.get_env("PROMETHEUS_AUTH_SECRET")}"
    auth = conn |> get_req_header("authorization") |> List.first()

    cond do
      auth == expected ->
        PromEx.Plug.call(conn, PromEx.Plug.init(prom_ex_module: StopMyHand.PromEx))
      true ->
        conn
        |> put_resp_header("www-authenticate", "Bearer")
        |> send_resp(401, "")
        |> halt()
    end
  end

  def call(conn, _opts), do: conn
end
