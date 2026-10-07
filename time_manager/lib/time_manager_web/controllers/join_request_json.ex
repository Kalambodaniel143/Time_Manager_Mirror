defmodule TimeManagerWeb.JoinRequestJSON do
  alias TimeManager.Organizations.JoinRequest
  alias TimeManagerWeb.UserJSON

  @doc "The receipt of a new request: the only response that carries no reason."
  def receipt(%{request: request, reference: reference}) do
    %{
      data: %{
        id: request.id,
        reference: reference,
        organization_name: request.organization.name,
        status: request.status
      }
    }
  end

  @doc "Public tracking: status and rejection reason only, never the profile."
  def status(%{request: request, reference: reference}) do
    %{
      data: %{
        id: request.id,
        reference: reference,
        organization_name: request.organization.name,
        status: request.status,
        rejection_reason: request.rejection_reason
      }
    }
  end

  def index(%{requests: requests}), do: %{data: Enum.map(requests, &data/1)}

  def show(%{request: request}), do: %{data: data(request)}

  def approved(%{request: request, user: user}) do
    %{data: %{request: data(request), user: UserJSON.data(user, true)}}
  end

  @doc "A request as its organization's administrators see it, without its reference."
  def data(%JoinRequest{} = request) do
    %{
      id: request.id,
      organization_id: request.organization_id,
      organization_name: request.organization.name,
      profile: JoinRequest.profile(request),
      status: request.status,
      created_at: request.inserted_at,
      reviewed_at: request.reviewed_at,
      reviewed_by: request.reviewed_by_id,
      rejection_reason: request.rejection_reason
    }
  end
end
