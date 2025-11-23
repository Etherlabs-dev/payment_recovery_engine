
---

## 2️⃣ `/docs/TEST_DATA.md` – Developer Test Guide + Sample Data

```markdown
# Payment Recovery Engine — Test Data Guide

This document defines **structured test scenarios** so developers can validate the workflows end-to-end.

---

## 1. Stripe Test Cards (Official)

Use these in **test mode**:​:contentReference[oaicite:12]{index=12}  

- **Expired card**
  - `4000000000000069`
  - Triggers `expired_card` failures

- **Insufficient funds**
  - `4000000000009995`
  - Triggers `insufficient_funds`

- **Generic decline / other**
  - `4000000000000002`
  - Triggers `card_declined` / `other`

---

## 2. Core Scenarios

### Scenario A — Expired Card (1 retry)

- Create customer `alice.expired@example.com`
- Create subscription for `$49.00`
- Use card: `4000000000000069`

**Expected:**

- `failed_payments` row:
  - `failure_category = 'expired_card'`
  - `max_retries = 1`
  - `retry_count = 0`
  - `next_retry_at ≈ now + 24h`
- Email:
  - Subject: “Action Required: Update Your Payment Method”
- No Slack alert
- On retry (if card updated to valid):
  - Status → `recovered`
  - `retry_attempts` row created
  - Recovery stats updated

---

### Scenario B — Insufficient Funds (3 retries)

- Customer: `bob.funds@example.com`
- Subscription: `$99.00`
- Card: `4000000000009995`

**Expected:**

- `failure_category = 'insufficient_funds'`
- `max_retries = 3`
- Retry schedule (example strategy):
  - Retry 1: 48h
  - Retry 2: +120h
  - Retry 3: +168h
- Each retry:
  - Logs a row into `retry_attempts`
  - Updates `retry_count` + `next_retry_at`
- If any retry succeeds:
  - `status = 'recovered'`
  - `recovered_at` set
  - Recovery stats updated

---

### Scenario C — Fraud Flag (no automatic retries)

- Customer: `carol.fraud@example.com`
- Force a `fraud_flag` type error (e.g., `do_not_honor` / `fraudulent` via Stripe test harness)

**Expected:**

- `failure_category = 'fraud_flag'`
- `max_retries = 0`
- `status = 'manual_review'`
- `next_retry_at = null`
- Slack alert sent to `SLACK_ALERT_CHANNEL`
- No retry attempts triggered

---

### Scenario D — Other Failures (fallback)

- Customer: `dan.other@example.com`
- Trigger generic decline with `4000000000000002`

**Expected:**

- `failure_category = 'other'`
- `max_retries = 1`
- `next_retry_at ≈ now + 72h`
- Email sent with generic “Payment Issue — Action Required”
- On retry:
  - Success → `status = 'recovered'`
  - Failure → `status = 'failed'`

---

## 3. Sample Supabase Seed Data

You can seed minimal data for UI/demo purposes with:

```sql
INSERT INTO failed_payments (
  stripe_payment_intent_id,
  stripe_customer_id,
  stripe_subscription_id,
  customer_email,
  customer_name,
  amount,
  currency,
  failure_code,
  failure_message,
  failure_category,
  retry_count,
  max_retries,
  next_retry_at,
  status
) VALUES
-- Expired card
('pi_test_expired_1', 'cus_test_1', 'sub_test_1',
 'alice.expired@example.com', 'Alice Expired',
 4900, 'usd', 'expired_card', 'Your card has expired',
 'expired_card', 0, 1, NOW() + INTERVAL '24 hours', 'pending'),

-- Insufficient funds
('pi_test_funds_1', 'cus_test_2', 'sub_test_2',
 'bob.funds@example.com', 'Bob Funds',
 9900, 'usd', 'insufficient_funds', 'Insufficient funds',
 'insufficient_funds', 0, 3, NOW() + INTERVAL '48 hours', 'pending'),

-- Fraud flag
('pi_test_fraud_1', 'cus_test_3', 'sub_test_3',
 'carol.fraud@example.com', 'Carol Fraud',
 14900, 'usd', 'do_not_honor', 'Card flagged by issuer',
 'fraud_flag', 0, 0, NULL, 'manual_review');
