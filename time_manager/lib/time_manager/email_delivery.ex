defmodule TimeManager.EmailDelivery do
  @moduledoc "Delivers verification emails through Mailpit locally or Resend in production."

  alias TimeManager.{Mailer, Resend}

  def send(email) do
    case Application.get_env(:time_manager, :email_delivery, :resend) do
      :mailpit ->
        case Mailer.deliver(email) do
          {:ok, _response} -> :ok
          {:error, reason} -> {:error, {:email_delivery_failed, reason}}
        end

      :resend ->
        Resend.send(email)
    end
  end
end
