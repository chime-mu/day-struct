defmodule DayStructWeb.BoardLiveTest do
  use DayStructWeb.ConnCase
  import Phoenix.LiveViewTest

  alias DayStruct.Store

  setup do
    Store.reset!()
    :ok
  end

  test "renders board with areas", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Board"
    assert html =~ "Work"
    assert html =~ "Physical movement"
    assert html =~ "Time with Trine"
    assert html =~ "Misc private"
    assert has_element?(view, "h1", "Board")
  end

  test "shows inbox count when items exist", %{conn: conn} do
    Store.capture("Test item")

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "1"
  end

  test "shows task counts per area", %{conn: conn} do
    [area | _] = Store.get_areas()
    Store.create_task(title: "Task A", area_id: area.id)
    Store.create_task(title: "Task B", area_id: area.id)

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "2 tasks"
  end
end
