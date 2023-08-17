defmodule FlyWeb.WebhookController do
  use FlyWeb, :controller

  def invoice_finalized(conn, %{"id" => invoice_id}) do
    if String.trim(invoice_id) == "" do
      send_resp(conn, 400, "Invalid id parameter")
    else
      case Fly.IncomingEvents.invoice_finalized(invoice_id) do
        {:ok, _} -> send_resp(conn, 200, "ok")
        {:error, _} -> send_resp(conn, 404, "Not found")
      end
    end
  end

  def invoice_finalized(conn, _params) do
    send_resp(conn, 400, "Missing id parameter")
  end
end
