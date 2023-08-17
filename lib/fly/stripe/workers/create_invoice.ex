defmodule Fly.Stripe.Workers.CreateInvoice do
  @moduledoc """
  Creates a Oban job that creates an Invoice in Stripe
  and updates the database Invoice with the Stripe invoice Id.

  This job is run async in dev/prod, and inline in test - meaning
  in test it will execute without setting up a job database record.

  It will retry 10 times before failing.
  If the error is not due to Stripe API, it will be discarded.
  """
  use Oban.Worker,
    queue: :stripe,
    priority: 1,
    max_attempts: 10

  alias Fly.Stripe
  alias Fly.Billing

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"customer_id" => customer_id, "invoice_id" => invoice_id}}) do
    with {:ok, %{id: stripe_id}} <- Stripe.create_invoice(customer_id),
         {:ok, invoice} <- get_billing_invoice(invoice_id) do
      Billing.update_invoice(invoice, %{stripe_id: stripe_id})
    else
      # This will need better error handling, to discard on parameter issues in API post
      # and report it.
      {:error, %Fly.Stripe.Error{}} = error -> error
      error -> {:discard, error}
    end
  end

  @doc """
  Create and insert a new #{__MODULE__} job into Oban.
  """
  @spec insert(customer_id :: binary(), invoice_id :: any(), oban_options :: keyword()) ::
          {:error, Oban.Job.changeset() | term()} | {:ok, Oban.Job.t()}
  def insert(customer_id, invoice_id, oban_options \\ [])
      when is_binary(customer_id) and not is_nil(invoice_id) do
    %{customer_id: customer_id, invoice_id: invoice_id}
    |> __MODULE__.new(oban_options)
    |> Oban.insert()
  end

  defp get_billing_invoice(invoice_id) do
    {:ok, Billing.get_invoice!(invoice_id)}
  rescue
    e ->
      {:error, e}
  end
end
