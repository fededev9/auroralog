defmodule AuraLogWeb.DashboardLiveTest do
  use AuraLogWeb.ConnCase, async: false

  test "renders dashboard and search form", %{conn: conn} do
    conn = get(conn, "/dashboard?q=api")
    body = html_response(conn, 200)
    assert body =~ "AuraLog Dashboard"
    assert body =~ "Search logs"
  end
end
