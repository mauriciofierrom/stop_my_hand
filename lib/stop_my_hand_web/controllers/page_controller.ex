defmodule StopMyHandWeb.PageController do
  use StopMyHandWeb, :controller
  use StopMyHandWeb, :live_component

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    page = if conn.assigns.current_user, do: :main, else: :home
    render(conn, page, layout: false)
  end
end
