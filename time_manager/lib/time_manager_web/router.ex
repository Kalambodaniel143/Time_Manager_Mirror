defmodule TimeManagerWeb.Router do
  use TimeManagerWeb, :router

  # CheckOrigin refuses POST/PUT/PATCH/DELETE sent by a browser from another
  # site, including on the public routes that have no CSRF token yet.
  pipeline :api do
    plug :accepts, ["json"]
    plug TimeManagerWeb.Plugs.CheckOrigin
    plug OpenApiSpex.Plug.PutApiSpec, module: TimeManagerWeb.ApiSpec
  end

  # Every protected request must carry the jwt cookie and a matching
  # X-CSRF-Token header; the plug assigns conn.assigns.current_user.
  pipeline :auth do
    plug TimeManagerWeb.Plugs.Authenticate
  end

  pipeline :session_restore do
    plug TimeManagerWeb.Plugs.Authenticate, session_restore: true
  end

  # Public routes: the only ones reachable without a session. Each one is
  # rate-limited in its controller.
  scope "/api", TimeManagerWeb do
    pipe_through :api

    post "/auth/login", AuthController, :login
    post "/auth/forgot-password", AuthController, :forgot_password
    post "/auth/reset-password", AuthController, :reset_password
    post "/auth/register", AdmissionPolicyController, :registration
    post "/auth/verify-email", AuthController, :verify_email
    post "/auth/resend-verification", AuthController, :resend_verification

    post "/organizations", AdmissionPolicyController, :organization
    get "/organizations/lookup", OrganizationController, :lookup
    post "/join-requests", JoinRequestController, :create
    post "/join-requests/verify-email", JoinRequestController, :verify_email
    post "/join-requests/resend-verification", JoinRequestController, :resend_verification
    post "/join-requests/status", JoinRequestController, :status
  end

  scope "/api", TimeManagerWeb do
    pipe_through [:api, :session_restore]
    get "/auth/session", AuthController, :session
  end

  scope "/api", TimeManagerWeb do
    pipe_through [:api, :auth]

    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout

    # Administrators of :org_id only (checked against the session, not the URL).
    scope "/organizations/:org_id" do
      get "/join-requests", JoinRequestController, :index
      post "/join-requests/:id/approve", JoinRequestController, :approve
      post "/join-requests/:id/reject", JoinRequestController, :reject
      get "/members", OrganizationController, :members
      patch "/members/:id", OrganizationController, :update_member
    end

    get "/roles", RoleController, :index

    get "/workforce/context", WorkforceController, :context
    get "/organizations/:org_id/rules", WorkforceController, :rules
    patch "/organizations/:org_id/rules", WorkforceController, :update_rules
    get "/teams/:id/permissions", WorkforceController, :permissions
    patch "/teams/:id/permissions", WorkforceController, :update_permissions
    get "/users/:user_id/week-notes/:week", WorkforceController, :notes
    put "/users/:user_id/week-notes/:week", WorkforceController, :update_notes
    get "/weekly-sheets", WorkforceController, :sheets
    post "/weekly-sheets/validate", WorkforceController, :validate_sheets
    post "/weekly-sheets/:user_id/:week/:action", WorkforceController, :transition_sheet
    get "/correction-requests", WorkforceController, :corrections
    post "/workingtime/:id/correction-requests", WorkforceController, :request_correction
    patch "/correction-requests/:id", WorkforceController, :review_correction
    get "/plans", WorkforceController, :plans
    get "/plans/:id", WorkforceController, :plan
    patch "/plans/:id", WorkforceController, :update_plan
    delete "/plans/:id", WorkforceController, :delete_plan
    post "/teams/:id/plans", WorkforceController, :create_plan
    post "/plans/:plan_id/shifts", WorkforceController, :create_shift
    put "/plans/:plan_id/shifts/:id", WorkforceController, :update_shift
    delete "/plans/:plan_id/shifts/:id", WorkforceController, :delete_shift
    post "/plans/:id/publish", WorkforceController, :publish
    get "/shift-swaps", WorkforceController, :swaps
    post "/shift-swaps", WorkforceController, :create_swap
    patch "/shift-swaps/:id/consent", WorkforceController, :consent_swap
    patch "/shift-swaps/:id", WorkforceController, :review_swap
    get "/absence-requests", WorkforceController, :absences
    post "/absence-requests", WorkforceController, :create_absence
    patch "/absence-requests/:id/payment", WorkforceController, :absence_payment
    post "/absence-requests/:id/cancel", WorkforceController, :cancel_absence
    patch "/absence-requests/:id", WorkforceController, :review_absence
    get "/payroll", WorkforceController, :payroll
    get "/payroll/export", WorkforceController, :payroll_csv
    get "/users/:id/payroll-profile", WorkforceController, :pay_profile
    put "/users/:id/payroll-profile", WorkforceController, :update_pay_profile
    get "/auth/preferences", WorkforceController, :preferences
    patch "/auth/preferences", WorkforceController, :update_preferences
    get "/audit-events", WorkforceController, :journal
    get "/notifications", WorkforceController, :notifications
    get "/notifications/count", WorkforceController, :notification_count
    patch "/notifications/:id/read", WorkforceController, :read_notification

    resources "/teams", TeamController, except: [:new, :edit]
    post "/teams/:id/members", TeamController, :add_member
    delete "/teams/:id/members/:user_id", TeamController, :remove_member

    get "/clocks/:userID", ClockController, :index
    post "/clocks/:userID", ClockController, :create
    post "/clocks/:userID/:clockID/complete", ClockController, :complete
    put "/users/:id/role", UserController, :update_role
    post "/users", AdmissionPolicyController, :user
    resources "/users", UserController, except: [:new, :edit, :create]

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
