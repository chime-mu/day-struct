defmodule DayStructWeb.Router do
  use DayStructWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DayStructWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", DayStructWeb do
    pipe_through :browser

    live "/", BoardLive
    live "/inbox", InboxLive
    live "/area/:id", AreaLive
    live "/day", DayPlanLive
    live "/day/:date", DayPlanLive
  end
end
