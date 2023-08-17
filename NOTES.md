# Notes

I'm including here notes on the process of solving the task at hand.

*Please feel free to check [the Case Study document](/CASE-STUDY.md) for general consideration on implementing Stripe. While the document provides a different opinion _scoped_ more towards the whole big problem, it is not required for this task and as such my implementation only partially focuses on some of the concepts.

## Approach

Given the scope of the problem, the solution is inherently more technical on the back-end side rather
than customer facing.

The proposed solution builds around the following strategy:

1. Have a cron job (via Oban) that at given intervals updates invoices at Stripe (called a Sync)
2. In order to have a harmony between Invoices and Subscription systems in Stripe, we'll consider billing cycles. Each billing cycle has one "draft" invoice that syncing updates items to; this is referred to as "current invoice".
3. As the customer attaches/detaches services, or sub-systems update usage info, Invoice Items are added/modified to the database.
4. Whenever a Customer or Support views the Billing page at Fly, a real-time overview of all the billing is fetched from the database. This will ensure Customer has quick access to the current billing state.
5. At the end of a billing cycle (incoming Event from Stripe) - before an invoice is to be finalized, a final Sync occurs. These events require monitoring and queueing, possibly via Broadway implementation.
6. Once an Invoice is finalized, a new "draft" invoice is created and run as the "current invoice".
7. Depending on use-cases, strategies to do Syncs outside the cron job window can be deployed for on-demand updates.

### Webhooks

Webhooks are set up via the following routes:

- `GET` [http://localhost:4000/webhook/invoice/finalized](http://localhost:4000/webhook/invoice/finalized?id=) - Handles `invoice.finalized` events. Each time an invoice
is finalized, a new "current invoice" is created by the handler.
- `GET` [http://localhost:4000/sync](http://localhost:4000/sync?invoice=) - On-demand trigger for `Sync.update_invoice` given an invoice ID.


### Limitations

- The scheduled Oban job to run `Sync.update_invoice/2` at regular intervals is not included
- Invoice update in `Sync` does not validate that a Stripe invoice has been created. It should check for this state, and if the invoice has not been created on Stripe end, but exists in the database, create it at Stripe too first.
- Invoice update in `Sync` does not validate against existing Stripe InvoiceItems. It should do so, and only compile
a list of changes for create/update/remove. Currently it only calls `Stripe.InvoiceItem.create/1`

## Final thoughts

The work put into this task is mostly for proof of concept, and not all relevant logic is in place (i.e. the scheduled job).

Also, the scope of implementing a complete billing system is much larger than what is presented in this repository,
and many models, routes and structure will change substantially, as redundancy and fault tolerance is implemented.
Moreover, business needs and logic also dictates the actual implementation and what and when gets built.

Overall, as stated in the Case Study document, the fundamental principles towards Customers is to minimize need of input from their behalf, be prompt and clear in the information supplied upon their request (either via UI tools or Support) and moreover, have the necessary features in place to make it transparent and allow them to control their billing subscriptions etc. by providing reliable tools;

When it comes to reliability, any solution should at least initially consider how much could be leveraged from 
already existing solutions (tested, reliable, common) for Customers - i.e. customer facing features provided by Stripe.

Thanks for reading and checking this out!

I hope we'll get to talk more about this topic
