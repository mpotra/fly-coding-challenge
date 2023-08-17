defmodule Fly.SyncTest do
  use Fly.DataCase, async: true
  use Oban.Testing, repo: Fly.Repo

  import Mox
  import Fly.OrganizationFixtures

  alias Fly.Sync
  alias Fly.Billing

  setup context do
    verify_on_exit!(context)

    :ok
  end

  describe "Sync Invoices" do
    setup do
      org = organization_fixture()

      {:ok, org: org}
    end

    test "creates an invoice", %{org: org} do
      due_date = DateTime.utc_now()
      expected_customer_id = org.stripe_customer_id

      Oban.Testing.with_testing_mode(:manual, fn ->
        # No previous job queued
        refute_enqueued(worker: Fly.Stripe.Workers.CreateInvoice)

        # Returns a Billing.Invoice
        assert {:ok, %Billing.Invoice{id: invoice_id}} = Sync.create_invoice(org, due_date)

        # Job enqueued for given customer id and Billing.Invoice id
        assert_enqueued(
          worker: Fly.Stripe.Workers.CreateInvoice,
          args: %{"customer_id" => expected_customer_id, "invoice_id" => invoice_id}
        )
      end)

      Fly.Stripe.InvoiceMock
      |> expect(:create, fn %{customer: ^expected_customer_id} = params ->
        Fly.Stripe.Invoice.create_record(params)
      end)

      assert {:ok, %Billing.Invoice{}} = Sync.create_invoice(org, due_date)
    end
  end
end
