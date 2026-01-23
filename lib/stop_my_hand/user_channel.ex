defmodule StopMyHandWeb.UserChannel do
  use StopMyHandWeb, :channel

  @impl true
  def join("user:" <> user_id, _payload, socket) do
    IO.inspect(socket.assigns.user, label: "User Channel socket's user joined")
    IO.inspect(user_id, label: "User Channel param's user joined")

    # Verify user is joining their own channel
    if socket.assigns.user == String.to_integer(user_id) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("webrtc_offer", %{"target" => target_id, "offer" => offer}, socket) do
    StopMyHandWeb.Endpoint.broadcast(
      "user:#{target_id}",
      "webrtc_offer",
      %{
        sender_id: socket.assigns.user,
        offer: offer
      }
    )

    {:noreply, socket}
  end

  @impl true
  def handle_in("webrtc_answer", %{"target" => target_id, "answer" => answer}, socket) do
    StopMyHandWeb.Endpoint.broadcast(
      "user:#{target_id}",
      "webrtc_answer",
      %{
        sender_id: socket.assigns.user,
        answer: answer
      }
    )

    {:noreply, socket}
  end

  @impl true
  def handle_in("webrtc_ice_candidate", %{"target" => target_id, "candidate" => candidate}, socket) do
    StopMyHandWeb.Endpoint.broadcast(
      "user:#{target_id}",
      "webrtc_ice_candidate",
      %{
        sender_id: socket.assigns.user,
        candidate: candidate
      }
    )

    {:noreply, socket}
  end
end
