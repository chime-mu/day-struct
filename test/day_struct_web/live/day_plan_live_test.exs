defmodule DayStructWeb.DayPlanLiveTest do
  use DayStructWeb.ConnCase
  import Phoenix.LiveViewTest

  alias DayStruct.Store

  setup do
    Store.reset!()
    :ok
  end

  test "renders timeline", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/day")

    assert html =~ "Day Plan"
    assert html =~ "Available Tasks"
  end

  test "shows empty state when no blocks", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/day")

    assert html =~ "No blocks scheduled yet"
    assert html =~ "Drag tasks from the sidebar"
  end

  test "shows available tasks in sidebar", %{conn: conn} do
    [area | _] = Store.get_areas()
    Store.create_task(title: "Ready task", area_id: area.id, status: "ready")

    {:ok, _view, html} = live(conn, ~p"/day")
    assert html =~ "Ready task"
  end

  test "sidebar shows improved empty state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/day")

    assert html =~ "No tasks to schedule"
    assert html =~ "Board"
  end

  test "renders specific date plan", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/day/2026-03-15")

    assert html =~ "Day Plan"
    assert html =~ "March"
  end
end
