defmodule StopMyHandWeb.Friendship.Search do
  use StopMyHandWeb, :live_view
  alias Phoenix.LiveView.AsyncResult
  alias StopMyHand.Friendship
  alias StopMyHandWeb.Endpoint

  def render(assigns) do
    ~H"""
    <h1>Search friend</h1>
    <.form for={%{}}>
      <.input id="search_friend" name="search_friend" value={""} phx-change="search_friend" phx-debounce/>
    </.form>
    <.async_result :let={results} assign={@results}>
      <:loading>Loading results...</:loading>
      <:failed :let={_failure}>there was an error fetching users</:failed>
      <div class={[
        "flex flex-col"
      ]}>
        <%= if !Enum.empty?(results) do %>
          <%= for result <- results do %>
            <.result_item user={result}/>
          <% end %>
        <% else %>
          No results
        <% end %>
      </div>
    </.async_result>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :results, AsyncResult.ok([]))}
  end

  def handle_event("search_friend", %{"search_friend" => ""}, socket) do
    {:noreply, socket |> assign(:results, AsyncResult.ok([]))}
  end

  def handle_event("search_friend", params, socket) do
    search_param = params["search_friend"]
    current_user = socket.assigns.current_user

    {:noreply,
    socket
    |> assign_async(:results, fn -> {:ok, %{results: Friendship.search_invitable_users(search_param, current_user)}} end)}
  end

  @doc """
  Handles the event to send Friendship invitations

  1. Send invite
  2. Remove the item from the entry from the current resultset
  3. Show a success flash notification
  """
  def handle_event("invite_friend", %{"userid" => userid}, socket) do
    current_user = socket.assigns.current_user
    res = Friendship.send_invite(%{invitee_id: current_user.id, invited_id: userid})
    case res do
      {:ok, invite} ->
        %{result: result} = socket.assigns.results
        filtered = Enum.filter(result, fn user -> user.id == userid end)

        Endpoint.broadcast("friends:#{userid}", "invite_received", %{invite_id: invite.id})

        {:noreply, put_flash(socket, :info, "Invitation sent") |> assign(:results, AsyncResult.ok(filtered))}
      _ -> {:noreply, put_flash(socket, :error, "Error when sending invite")}
    end
  end

  defp result_item(assigns) do
    ~H"""
    <div
      class={[
        "flex flex-row"
    ]}>
      <div class="basis--2/3"><%= assigns.user.username %></div>
      <button class="btn btn-blue" id={ "invite-#{assigns.user.id}" } phx-hook="ConfirmInvite" data-userid={ assigns.user.id }>Invite</button>
    </div>
    """
  end
end
