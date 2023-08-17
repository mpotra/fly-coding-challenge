# Case Study - billing system

The goal of the project is providing customers with the ability to view and pay invoices via Stripe.

Currently, invoices are created and updated by aggressively pushing small increments to Stripe via API.

## Issue

Due to the high volume of API calls to Stripe, the sync of invoices may sometimes fail.

### Proposed solution

In order to reduce the amount of API calls and solve the issue, the proposal is to create an invoice handling system that keeps track of items to be invoiced and at billing cycle creates an invoice and syncs it with the compiled list of invoice items.

This solution involves:

- Providing the Fly Billing panel as the single source of truth for billing status
- Maintaining billing data in persistent storage - *at least until invoices are finalized*
- Provide Support with a specialized tool/UI to intervene before an Invoice is finalized

## Assessment

The proposed solution is indeed a valid option given the context of incremental billing changes that happen at a *high frequency*, coupled with Stripe *(a 3rd party service)* where availability and rate limits are outside the control of Fly.

However, when implementing Stripe, there are some key aspects that need to be considered for an effective implementation:

1. Customers do not care about implementation specifics

2. Customers need a quick and easy way of understanding their billing; *billing needs to be transparent and real-time.*

3. Customers need Support that solves billing issues effectively and quickly; *they never care about system or implementation shortcomings.*

4. Billing issues are inevitable, and can arise at any moment due to the wide network of provisioned services and their inter-operability, sync issues between Fly and Stripe (API availability issues), payment processing issues, sometimes even customer error.

5. To solve customer billing issues, Support needs to also have access to fast and easy methods of inspecting and correcting billing issues.

Given the above, the proposed solution should factor in two main requirements:

- For the Customer: Tools for accurate and easy to access billing information
- For Support: Tools for easy and effective billing issue solving

## Tools provided by Stripe

Stripe already provides a fairly extensive set of tools, aside API, that would provide Support and Customers with the necessary features to effectively view and manage invoices, billing and payments.

1. Client Dashboard - UI where Support members can have restricted access to manage Customer related issues in Stripe
2. Customer Portal - UI where customers can access their billing information and operate on invoices and payments

Because Stripe already offers tools for effective management of billing, any implementation should consider the principle of separation of concerns and build around Stripe capabilities so that these features are leveraged instead of replicated.

Replicating features Stripe already has, would lead to slow development and costly maintenance of these features, which I consider not to be a viable strategy - *unless business constraints prevent leveraging these already built features.*

Futhermore, Support that would need to solve Customer issues, will now have to expend effort in two directions, depending on Invoice state and type of billing issue: one using Stripe Dashboard and one using the tool to inspect real-time (source of truth) data - which might lead to a slower rate of solving Customer issues timely and effectively.

## Alternate solution

Considering that Stripe **already provides** the set of tools needed to satisfy the key aspects listed in [Assessment](#assessment) chapter, and the following ideal strategy:

1. Fly: determines what and when to bill customers
2. Stripe: bill and collect customer payments.

and that the **main identified issue** is with syncing of invoices due to **API bandwidth/computing constraints**, an effective possible solution would involve the following:

1. Keep syncing invoices at Stripe, but reduce the amount of syncs by compiling only invoice updates at regular intervals, instead of a single invoice compile at end of cycle.
2. Sync compiled invoice updates on-demand. *i.e. when the user accesses the Customer Portal, or by other means to request billing data is updated in Stripe.*
3. Fly Billing dashboard would read billing data from Stripe, on-demand. *This can also be cached to improve access times.*

Advantages:

- Access to the tools provided by Stripe is not hindered by the in-house billing system capabilities.
- Minimal chances of data discrepancies between what the Customer or Support views (past and upcoming billing) and actual amounts to be charged.
- Less effort in building an in-house billing system and solving its complexities that Stripe already solves.
- A more controlled flow of updates that can be fine-tuned based on business requirement realities.
- Less maintenance required once solution is implemented accordingly.

Disadvantages:

- Requires extensive Stripe API understanding, especially around Webhooks and different states throughout invoice cycles.
- Requires an established contact line with Stripe engineers for support and assistance - *Stripe API is not always accurate or enough to understand edge-cases.*
- Engineering will need to consider potential scaling issues *(i.e. event processing, timings etc - Broadway or other streaming strategies are needed)*

## Disclaimer note

All of the above starts from several assumptions that may or may not be valid or how Fly currently operates, or how the current Stripe implementation works. As such, this document should be read more as an overview on a possible scenario than an accurate analysis of the current state.
