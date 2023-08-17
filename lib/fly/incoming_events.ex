defmodule Fly.IncomingEvents do
  @moduledoc """
  Module that handles Incoming events from Stripe
  (webhooks)
  """

  alias Fly.Billing
  alias Fly.Sync

  @doc """
  Handle Webhook event on Invoice finalized.

  BUG! Calling multiple times on this function, creates a new invoice
  every time, because there is no check on whether the invoice in the Database
  has already been marked as finalized
  """
  def invoice_finalized(invoice_id) do
    invoice_id
    |> Billing.find_invoice_by_stripe_id(preload: [:organization])
    |> case do
      {:ok, %{organization: org}} ->
        # Sets up a new current invoice.
        Sync.create_invoice(org, DateTime.utc_now())

      error ->
        error
    end
  end
end
