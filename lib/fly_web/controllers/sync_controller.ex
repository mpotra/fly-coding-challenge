defmodule FlyWeb.SyncController do
  @moduledoc """
  A Controller that provides handling for manual triggers
  of invoice syncs.

  Just for playing purposes
  """
  use FlyWeb, :controller

  def update_invoice(conn, %{"invoice" => invoice_id}) do
    if String.trim(invoice_id) == "" do
      send_resp(conn, 400, "Invalid id parameter")
    else
      case Fly.Sync.update_invoice(invoice_id) do
        {:ok, _} -> send_resp(conn, 200, "ok")
        {:error, _} -> send_resp(conn, 404, "Not found")
      end
    end
  end

  def update_invoice(conn, _params) do
    send_resp(conn, 400, "Missing id parameter")
  end
end
