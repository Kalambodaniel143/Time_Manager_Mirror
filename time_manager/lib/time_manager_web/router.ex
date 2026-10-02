defmodule TimeManagerWeb.Router do
  use TimeManagerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: TimeManagerWeb.ApiSpec
  end

  scope "/api", TimeManagerWeb do
    pipe_through :api

    get "/clocks/:userID", ClockController, :index
    post "/clocks/:userID", ClockController, :create
    resources "/users", UserController, except: [:new, :edit]

    scope "/workingtime" do
      get "/:userID", WorkingTimeController, :index
      get "/:userID/:id", WorkingTimeController, :show
      post "/:userID", WorkingTimeController, :create
      put "/:id", WorkingTimeController, :update
      delete "/:id", WorkingTimeController, :delete
    end
  end

  scope "/api" do
    pipe_through :api

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/" do
    get "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/openapi",
      title: "Time Manager API"
  end

  if Application.compile_env(:time_manager, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: TimeManagerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
