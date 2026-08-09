# Payment Recovery Engine

> Reference implementation for classifying payment failures, applying policy-driven retry strategies, notifying customers, and tracking recovery operations.

**Status:** Reference Implementation / Validation Candidate  
**Domain:** Payments · Revenue Recovery · Finance Operations  
**Stack:** n8n · Supabase/PostgreSQL · Stripe webhooks · Email/Slack

This repository demonstrates the architecture of a failed-payment recovery system. It models how recurring-payment failures can move from a webhook event into classification, retry scheduling, customer communication, recovery tracking and operational alerting.

It is **not presented as a verified client deployment**. Recovery-rate, revenue and time-savings figures must be treated as modeled or simulated unless a reproducible benchmark or production evidence is attached.

---

## Problem

Recurring-payment failures create avoidable churn and lost revenue, but a reliable recovery system has to do more than retry every card on a fixed schedule.

The system needs to distinguish failure types, avoid unsafe retries, preserve idempotency, respect provider limits, and make every action auditable.

---

## System flow

```text
Stripe payment failure
        ↓
webhook intake
        ↓
verify + persist event
        ↓
classify failure reason
        ↓
policy / retry strategy
   ┌────┼─────────────┐
   ↓    ↓             ↓
expired insufficient fraud/security
card    funds        signal
   ↓    ↓             ↓
notify  scheduled    manual review /
user    retries      no automatic retry
   └────┴─────────────┘
        ↓
recovery tracking
        ↓
metrics + alerts
```

---

## Repository artifacts

The repository contains:

- database schema and sample data;
- n8n workflow exports;
- customer email templates;
- installation/testing documentation;
- test webhook/sample data;
- contribution and licensing files.

The `tests/` directory currently contains test data rather than a substantive automated test suite. That distinction is important: test fixtures are **not the same as executable regression coverage**.

---

## Recovery policy represented in the reference design

The existing workflow design uses different policies by failure class rather than a universal retry loop.

### Expired / invalid payment method
- customer notification;
- limited retry after the customer has had time to update the payment method.

### Insufficient funds
- staged retries across a bounded time window;
- customer reminders;
- stop conditions after the configured retry budget is exhausted.

### Fraud/security signal
- no blind automatic retry;
- escalation/manual review path.

### Other failures
- conservative retry policy with explicit limits.

These policies are reference defaults, not universal payment-network rules. A production implementation should map provider-specific decline codes into a reviewed policy table.

---

## Evidence standard

| Claim | Evidence status |
|---|---|
| Workflow artifacts exist | **Implemented** |
| Database/schema artifacts exist | **Implemented** |
| Failure categories and retry-policy design exist | **Implemented** |
| Test webhook fixtures exist | **Synthetic / Demonstration** |
| Automated regression suite | **Not yet established** |
| 28–35% recovery rate | **Not verified by this repo** |
| 3× recovery improvement | **Not verified by this repo** |
| $12K–15K/month recovered | **Not verified by this repo** |
| 96% time reduction | **Not verified by this repo** |
| Production SLA/throughput | **Not claimed** |

See [`docs/EVIDENCE.md`](./docs/EVIDENCE.md).

---

## Reliability requirements

A production payment-recovery service must be safe under retries, duplicate provider events, process restarts and changing customer state.

Key controls include:

- Stripe webhook signature verification;
- unique event/idempotency keys;
- durable retry state;
- duplicate-event suppression;
- bounded retry budgets;
- provider decline-code mapping;
- stop conditions after successful recovery/cancellation;
- concurrency protection so two retries cannot race;
- structured audit logs;
- customer-notification deduplication;
- rate-limit handling;
- dead-letter / failed-event recovery;
- explicit manual-review paths for security signals.

See [`docs/RELIABILITY.md`](./docs/RELIABILITY.md).

---

## Quick start

### Prerequisites

- n8n
- Supabase/PostgreSQL
- Stripe test-mode account
- email provider; Slack optional

### 1. Clone

```bash
git clone https://github.com/Etherlabs-dev/payment_recovery_engine.git
cd payment_recovery_engine
```

### 2. Create the database

Use the schema under `database/` and load sample data only for testing/demo purposes.

### 3. Import workflows

Import the workflow JSON files from `n8n-workflows/` and configure credentials through n8n rather than hardcoding secrets.

### 4. Test safely

Use Stripe **test mode** and the repository's sample webhook fixtures. Do not use live payment credentials until the implementation has passed idempotency and retry-safety testing.

---

## What should be strengthened in the portfolio version

The current repository is workflow-heavy. To demonstrate senior financial-systems engineering more clearly, the next pass should move the deterministic payment-recovery policy into independently testable code.

A stronger architecture would use:

```text
provider webhook
      ↓
validated event adapter
      ↓
recovery policy engine  ← unit-tested Python
      ↓
state/retry scheduler
      ↓
orchestration / notifications (n8n)
```

The policy engine should accept normalized failure data and return an explicit action plan such as:

```text
classification
retry_allowed
next_retry_at
max_attempts
customer_notification
manual_review_required
reason
```

That creates a clear separation between **business rules** and **workflow orchestration**.

---

## Testing target

The upgrade should add executable tests for at least:

- webhook-signature validation;
- duplicate event delivery;
- expired-card classification;
- insufficient-funds retry schedule;
- fraud/security no-retry behavior;
- successful recovery cancelling future retries;
- retry-budget exhaustion;
- notification deduplication;
- malformed event payload;
- concurrent/replayed event handling.

---

## Limitations

- Existing result numbers in the previous README were not backed by a reproducible client evidence package in this repository.
- `docs/CONFIGURATION.md` and `docs/TROUBLESHOOTING.md` are currently placeholder files and need substantive content.
- Existing tests are primarily fixture/sample data, not automated assertions.
- Provider decline semantics change and must be validated against current Stripe documentation before live deployment.
- Email and retry behavior must respect the client's billing policy, customer terms and jurisdiction.

---

## License

MIT. See [`LICENSE`](./LICENSE).

---

Built by **Ugo Chukwu / Etherlabs** as a payments and revenue-recovery reference implementation.