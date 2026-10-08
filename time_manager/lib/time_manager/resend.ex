defmodule TimeManager.Resend do
  @moduledoc "Minimal Resend API client used for verification emails."

  require Logger

  def send(email) do
    api_key = System.get_env("RESEND_API_KEY")

    if is_nil(api_key) or api_key == "" do
      Logger.error("RESEND_API_KEY is not configured")
      {:error, :email_delivery_failed}
    else
      send_request(email, api_key)
    end
  end

  defp send_request(email, api_key) do
    body = %{
      from: Application.fetch_env!(:time_manager, :resend_from),
      to: [email.to],
      subject: email.subject,
      text: email.text_body
    }

    case Req.post("https://api.resend.com/emails",
           auth: {:bearer, api_key},
           json: body
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: response}} ->
        Logger.error("Resend rejected email (status #{status}): #{inspect(response)}")
        {:error, :email_delivery_failed}

      {:error, reason} ->
        Logger.error("Resend request failed: #{inspect(reason)}")
        {:error, :email_delivery_failed}
    end
  end
end
