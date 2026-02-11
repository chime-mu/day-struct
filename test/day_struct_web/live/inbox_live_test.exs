defmodule DayStructWeb.InboxLiveTest do
  use DayStructWeb.ConnCase
  import Phoenix.LiveViewTest

  alias DayStruct.Store

  setup do
    Store.reset!()
    :ok
  end

  test "renders empty inbox state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/inbox")

    assert html =~ "Inbox"
    assert html =~ "Inbox is empty"
  end

  test "capture adds item to inbox", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/inbox")

    view
    |> form("form", %{text: "New thought"})
    |> render_submit()

    html = render(view)
    assert html =~ "New thought"
  end

  test "discard removes item from inbox", %{conn: conn} do
    {:ok, item} = Store.capture("Remove me")

    {:ok, view, html} = live(conn, ~p"/inbox")
    assert html =~ "Remove me"

    view
    |> element(~s{button[phx-click="discard"][phx-value-id="#{item.id}"]})
    |> render_click()

    html = render(view)
    refute html =~ "Remove me"
  end
end
