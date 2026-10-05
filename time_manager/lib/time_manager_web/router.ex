defmodule TimeManagerWeb.Router do
  use TimeManagerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: TimeManagerWeb.ApiSpec
  end

  # Every protected request must carry the jwt cookie and a matching
  # X-CSRF-Token header; the plug assigns conn.assigns.current_user.
  pipeline :auth do
    plug TimeManagerWeb.Plugs.Authenticate
  end

  # Public routes: the only ones reachable without a session.
  scope "/api/auth", TimeManagerWeb do
    pipe_through :api

    post "/login", AuthController, :login
    post "/register", AuthController, :register
  end

  scope "/api", TimeManagerWeb do
    pipe_through [:api, :auth]

    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout

    get "/roles", RoleController, :index

    resources "/teams", TeamController, except: [:new, :edit]
    post "/teams/:id/members", TeamController, :add_member
    delete "/teams/:id/members/:user_id", TeamController, :remove_member

    get "/clocks/:userID", ClockController, :index
    post "/clocks/:userID", ClockController, :create
    post "/clocks/:userID/:clockID/complete", ClockController, :complete
    put "/users/:id/role", UserController, :update_role
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
