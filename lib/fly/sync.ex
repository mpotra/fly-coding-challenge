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

  @doc """
  Updates an invoice, by calling Stripe.InvoiceItem API
  and any additional invoice updates needed.
  """
  def update_invoice(%Billing.Invoice{} = invoice) do
    # TODO: Check with Stripe if the invoice already exists.
    # if not, then make sure to create it in Stripe as well first
    # and then continue with the bellow logic.

    update_invoice_items(invoice)
  end

  def update_invoice(invoice_id) do
    case Billing.get_invoice(invoice_id, preload: [:invoice_items]) do
      {:ok, invoice} -> update_invoice(invoice)
      error -> error
    end
  end

  @doc """
  This is a dummy function that should check with Stripe for existing items,
  determine which ones need to be updated, removed or added, and use
  the appropriate API call for each item.

  For the time being this just calls create for all.
  Does not manage errors.

  This can be an async call (via Oban jobs) so that individual failing
  calls can be retried.
  """
  def update_invoice_items(
        %Billing.Invoice{stripe_id: stripe_invoice_id, invoice_items: invoice_items} = invoice
      ) do
    Enum.each(invoice_items, fn invoice_item ->
      Fly.Stripe.api_module(:invoice_item).create(%{
        invoice: stripe_invoice_id,
        unit_amount_decimal: invoice_item.amount,
        quantity: 1
      })
    end)

    {:ok, invoice}
  end
end
