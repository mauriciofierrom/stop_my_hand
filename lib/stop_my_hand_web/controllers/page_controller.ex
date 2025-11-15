defmodule StopMyHandWeb.PageController do
  use StopMyHandWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    if conn.assigns.current_user do
      Phoenix.Controller.redirect(conn, to: ~p"/main")
    else
      render(conn, :home, layout: false)
    end
  end
end
