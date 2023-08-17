defmodule FlyWeb.SyncControllerTest do
  use FlyWeb.ConnCase

  import Fly.BillingFixtures
  import Fly.OrganizationFixtures
  import Mox

  setup context do
    verify_on_exit!(context)

    :ok
  end

  describe "GET /sync" do
    test "returns error on missing parameter", %{conn: conn} do
      conn = get(conn, ~p"/sync")
      assert response(conn, 400) =~ "Missing id parameter"
    end

    test "returns error on invoice not found", %{conn: conn} do
      conn = get(conn, ~p"/sync", invoice: 10_999_999)
      assert response(conn, 404) =~ "Not found"
    end

    test "returns ok for valid invoice", %{conn: conn} do
      org = organization_fixture()
      invoice = invoice_fixture(org)
      invoice_item_fixture(invoice, amount: 10.99, description: "Item 1")
      invoice_item_fixture(invoice, amount: 12.99, description: "Item 2")
      invoice_item_fixture(invoice, amount: 15.99, description: "Item 3")

      # Update invoice
      invoice = Fly.Billing.get_invoice!(invoice.id, preload: [:invoice_items])

      assert 3 == Enum.count(invoice.invoice_items)

      expected_stripe_invoice_id = invoice.stripe_id
      # Register mock expectations for all invoice items
      Fly.Stripe.InvoiceItemMock
      |> expect(:create, Enum.count(invoice.invoice_items), fn %{
                                                                 invoice:
                                                                   ^expected_stripe_invoice_id
                                                               } = params ->
        Fly.Stripe.InvoiceItem.create_record(params)
      end)

      conn = get(conn, ~p"/sync", invoice: invoice.id)
      assert response(conn, 200) =~ "ok"
    end
  end
end
