defmodule DayStructWeb.AreaLiveTest do
  use DayStructWeb.ConnCase
  import Phoenix.LiveViewTest

  alias DayStruct.Store

  setup do
    Store.reset!()
    [area | _] = Store.get_areas()
    %{area: area}
  end

  test "renders area name", %{conn: conn, area: area} do
    {:ok, _view, html} = live(conn, ~p"/area/#{area.id}")

    assert html =~ area.name
  end

  test "can create a task", %{conn: conn, area: area} do
    {:ok, view, _html} = live(conn, ~p"/area/#{area.id}")

    view
    |> form(~s{form[phx-submit="create_task"]}, %{title: "New area task"})
    |> render_submit()

    html = render(view)
    assert html =~ "New area task"
  end

  test "redirects for invalid area id", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/area/nonexistent")
  end
end
