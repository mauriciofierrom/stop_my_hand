defmodule StopMyHand.Plugs.Locale do
  import Plug.Conn

  @supported_locales ["en", "es"]

  def init(default), do: default

  def call(conn, _default) do
    locale =
      get_session(conn, :locale) ||
      get_locale_from_header(conn) ||
      "en"

    Gettext.put_locale(StopMyHandWeb.Gettext, locale)
    put_session(conn, :locale, locale)
  end

  defp get_locale_from_header(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first()
    |> parse_language_header()
    |> Enum.find(&(&1 in @supported_locales))
  end

  defp parse_language_header(nil), do: []
  defp parse_language_header(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.split(&1, ";"))
    |> Enum.map(&List.first/1)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.split(&1, "-"))
    |> Enum.map(&List.first/1)
  end
end
