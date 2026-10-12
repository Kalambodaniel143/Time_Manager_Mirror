defmodule TimeManagerWeb.AdmissionPolicyController do
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias TimeManagerWeb.Schemas.ErrorResponse
  tags(["admission"])

  operation(:registration,
    summary: "Direct registration disabled",
    security: [],
    responses: [forbidden: {"Use admission requests", "application/json", ErrorResponse}]
  )

  def registration(conn, _params), do: disabled(conn)

  operation(:organization,
    summary: "Public organization creation disabled",
    security: [],
    responses: [forbidden: {"Manual provisioning only", "application/json", ErrorResponse}]
  )

  def organization(conn, _params), do: disabled(conn)

  operation(:user,
    summary: "Direct user creation disabled",
    responses: [forbidden: {"Use admission requests", "application/json", ErrorResponse}]
  )

  def user(conn, _params), do: disabled(conn)

  defp disabled(conn),
    do:
      conn
      |> put_status(:forbidden)
      |> json(%{
        errors: %{
          detail:
            "La création directe est désactivée. Envoyez une demande pour rejoindre Gotham City."
        }
      })
end
