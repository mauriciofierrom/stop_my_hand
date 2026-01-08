defmodule StopMyHandWeb.LocaleHook do
  use StopMyHandWeb, :live_view

  def on_mount(:default, _params, session, socket) do
    locale = session["locale"] || "en"
    Gettext.put_locale(StopMyHandWeb.Gettext, locale)
    {:cont, assign(socket, locale: locale)}
  end
end
