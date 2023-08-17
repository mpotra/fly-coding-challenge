defmodule Fly.Sync do
  @moduledoc """
  Module that handles billing operations for a customer
  """

  alias Fly.Organizations.Organization
  alias Fly.Billing
  alias Fly.Repo

  @doc """
  Create a new Invoice record in the database.

  It will additionally create a sync job to create a Stripe Invoice,
  and once that invoice is created, it will update the database Invoice
  with the stripe_id

  See Fly.Stripe.Workers.CreateInvoice job module for Oban
  """
  def create_invoice(
        %Organization{stripe_customer_id: customer_id} = org,
        due_date
      ) do
    # Wrap everything in a transaction so that if any database record inserts
    # fail, then the whole transaction fails and records are reverted.
    #
    # Example is there is a failure in queueing the job. Then the Billing.Invoice
    # record is reverted and an error returned to the call.
    # If inserting a Billing.Invoice fails, then the job is not even created.
    Repo.transaction(fn ->
      with {:ok, invoice} <-
             Billing.create_invoice(org, %{
               stripe_id: nil,
               due_date: due_date,
               invoiced_at: DateTime.utc_now()
             }),
           {:ok, _job} <-
             Fly.Stripe.Workers.CreateInvoice.insert(customer_id, invoice.id) do
        invoice
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end
