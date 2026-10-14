defmodule TimeManager.EmailDelivery do
  @moduledoc "Delivers verification emails through Mailpit locally or Resend in production."

  alias TimeManager.{Mailer, Resend}
  require Logger

  @doc "Dispatch recovery mail without making public response time depend on the provider."
  def send_later(email) do
    deliver = fn ->
      case send(email) do
        :ok -> :ok
        {:error, _} -> Logger.error("Password recovery email delivery failed")
      end
    end

    if Application.get_env(:time_manager, :email_delivery) == :test do
      # Keep the Swoosh test mailbox in the calling, sandboxed test process.
      deliver.()
    else
      case Task.Supervisor.start_child(TimeManager.EmailTasks, deliver) do
        {:ok, _pid} -> :ok
        {:error, _} -> Logger.error("Password recovery email could not be scheduled")
      end
    end

    :ok
  end

  def send(email) do
    case Application.get_env(:time_manager, :email_delivery, :resend) do
      mode when mode in [:mailpit, :test] ->
        case Mailer.deliver(email) do
          {:ok, _response} -> :ok
          {:error, _reason} -> {:error, :email_delivery_failed}
        end

      :resend ->
        Resend.send(email)
    end
  rescue
    _ -> {:error, :email_delivery_failed}
  end
end
