defmodule FlyWeb.WebhookControllerTest do
  use FlyWeb.ConnCase

  import Fly.BillingFixtures
  import Fly.OrganizationFixtures
  import Mox

  setup context do
    verify_on_exit!(context)

    :ok
  end

  describe "GET /invoice/finalized" do
    test "returns error on missing parameter", %{conn: conn} do
      conn = get(conn, ~p"/webhook/invoice/finalized")
      assert response(conn, 400) =~ "Missing id parameter"
    end

    test "returns error on invoice not found", %{conn: conn} do
      conn = get(conn, ~p"/webhook/invoice/finalized", id: "nope")
      assert response(conn, 404) =~ "Not found"
    end

    test "returns ok for valid invoice", %{conn: conn} do
      org = organization_fixture()
      stripe_invoice_id = Fly.Stripe.Invoice.generate_id()
      _invoice = invoice_fixture(org, %{stripe_id: stripe_invoice_id})

      expected_customer_id = org.stripe_customer_id

      Fly.Stripe.InvoiceMock
      |> expect(:create, fn %{customer: ^expected_customer_id} = params ->
        Fly.Stripe.Invoice.create_record(params)
      end)

      conn = get(conn, ~p"/webhook/invoice/finalized", id: stripe_invoice_id)
      assert response(conn, 200) =~ "ok"
    end
  end
end
