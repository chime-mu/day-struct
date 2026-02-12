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
    |> form(~s{form[phx-submit="capture"]}, %{text: "New thought"})
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

  describe "bulk import" do
    test "toggle_bulk shows and hides bulk import section", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/inbox")
      refute html =~ "Paste Logseq journal entries here"

      html = view |> element(~s{button[phx-click="toggle_bulk"]}) |> render_click()
      assert html =~ "Paste Logseq journal entries here"

      html = view |> element(~s{button[phx-click="toggle_bulk"]}, "Bulk Import") |> render_click()
      refute html =~ "Paste Logseq journal entries here"
    end

    test "pasting text generates preview", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inbox")
      view |> element(~s{button[phx-click="toggle_bulk"]}) |> render_click()

      html = view |> render_change("bulk_parse", %{"bulk_text" => "Buy milk\nCall dentist"})
      assert html =~ "Buy milk"
      assert html =~ "Call dentist"
      assert html =~ "2 of 2 items selected"
    end

    test "toggling item deselects it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inbox")
      view |> element(~s{button[phx-click="toggle_bulk"]}) |> render_click()
      view |> render_change("bulk_parse", %{"bulk_text" => "Item A\nItem B"})

      html = view |> render_click("bulk_toggle_item", %{"index" => "0"})
      assert html =~ "1 of 2 items selected"
    end

    test "importing adds selected items to inbox", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inbox")
      view |> element(~s{button[phx-click="toggle_bulk"]}) |> render_click()
      view |> render_change("bulk_parse", %{"bulk_text" => "Task one\nTask two\nTask three"})

      view |> render_click("bulk_import")
      html = render(view)
      assert html =~ "Task one"
      assert html =~ "Task two"
      assert html =~ "Task three"

      items = Store.get_inbox_items()
      assert length(items) == 3
    end

    test "importing with deselected items only adds selected ones", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inbox")
      view |> element(~s{button[phx-click="toggle_bulk"]}) |> render_click()
      view |> render_change("bulk_parse", %{"bulk_text" => "Keep me\nSkip me"})
      view |> render_click("bulk_toggle_item", %{"index" => "1"})

      view |> render_click("bulk_import")
      html = render(view)
      assert html =~ "Keep me"

      items = Store.get_inbox_items()
      assert length(items) == 1
      assert hd(items).text == "Keep me"
    end

    test "bulk import closes after successful import", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inbox")
      view |> element(~s{button[phx-click="toggle_bulk"]}) |> render_click()
      view |> render_change("bulk_parse", %{"bulk_text" => "New item"})

      html = view |> render_click("bulk_import")
      refute html =~ "Paste Logseq journal entries here"
    end
  end
end
