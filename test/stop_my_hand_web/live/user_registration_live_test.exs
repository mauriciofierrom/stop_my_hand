defmodule StopMyHandWeb.UserRegistrationLiveTest do
  use StopMyHandWeb.ConnCase

  import Phoenix.LiveViewTest
  import StopMyHand.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Register"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short", "username" => "_123"})

      assert result =~ "Register"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
      assert result =~ "must only contain letters and numbers"
      assert result =~ "should be at least 5 character(s)"

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"username" => "1234567891231234"})

      assert result =~ "should be at most 15 character(s)"
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")

      assert redirected_to(conn, 302) =~ "/main"

      {:ok, _lv, html} = live(conn, ~p"/main")

      assert html =~ email
      assert html =~ "Settings"
      assert html =~ "Log out"
      assert html =~ "Stop My Hand"
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  test "renders errors for duplicated username", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/users/register")

    user = user_fixture(%{email: "test@email.com", username: "username"})

    result =
      lv
      |> form("#registration_form",
        user: %{"email" => user.email, "password" => "valid_password", "username" => user.username}
      )
      |> render_submit()

    assert result =~ "has already been taken"
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element(~s|main a:fl-contains("Sign in")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert login_html =~ "Log in"
    end
  end
end
