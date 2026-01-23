defmodule StopMyHandWeb.IceServerController do
  use StopMyHandWeb, :controller

  alias HTTPoison

  def ice_servers(conn, _params) do
    api_key = System.get_env("OPENRELAY_API_KEY")

    case HTTPoison.get("https://stop-my-hand.metered.live/api/v1/turn/credentials?apiKey=#{api_key}") do
      {:ok, %{body: body}} ->
        IO.inspect(body, label: "The openrelay response")
        json(conn, Jason.decode!(body))
      {:error, m} ->
        IO.inspect(m)
        # Fallback to public STUN
        json(conn, [%{urls: "stun:stun.l.google.com:19302"}])
    end
  end
end
