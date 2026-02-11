defmodule DayStructWeb.PageControllerTest do
  use DayStructWeb.ConnCase

  test "GET / redirects to board live view", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Board"
  end
end
