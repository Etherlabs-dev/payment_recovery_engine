# Testing Guide for Failed Payment Recovery Engine

## Complete Testing Strategy + Sample Data

This guide provides step-by-step testing procedures and sample data to verify your Failed Payment Recovery Engine works correctly before production.

---

## Testing Philosophy

**Test in this order:**
1. ✅ Component Testing (each workflow individually)
2. ✅ Integration Testing (workflows together)
3. ✅ End-to-End Testing (full user journey)
4. ✅ Edge Case Testing (unusual scenarios)
5. ✅ Load Testing (high volume)

---

## Part 1: Sample Test Data

### Sample Failed Payment Webhooks

Save these as JSON files in `/tests/test-data/sample-webhooks.json`:

#### Test Case 1: Expired Card

```json
{
  "id": "evt_test_expired_card_001",
  "object": "event",
  "type": "payment_intent.payment_failed",
  "data": {
    "object": {
      "id": "pi_test_expired_card_001",
      "object": "payment_intent",
      "amount": 4999,
      "currency": "usd",
      "customer": "cus_test_001",
      "subscription": "sub_test_001",
      "receipt_email": "test.customer@example.com",
      "last_payment_error": {
        "code": "expired_card",
        "message": "Your card has expired.",
        "decline_code": "expired_card",
        "type": "card_error"
      },
      "status": "requires_payment_method"
    }
  }
}
```

#### Test Case 2: Insufficient Funds

```json
{
  "id": "evt_test_insufficient_001",
  "object": "event",
  "type": "payment_intent.payment_failed",
  "data": {
    "object": {
      "id": "pi_test_insufficient_001",
      "object": "payment_intent",
      "amount": 9999,
      "currency": "usd",
      "customer": "cus_test_002",
      "subscription": "sub_test_002",
      "receipt_email": "jane.doe@example.com",
      "last_payment_error": {
        "code": "insufficient_funds",
        "message": "Your card has insufficient funds.",
        "decline_code": "insufficient_funds",
        "type": "card_error"
      },
      "status": "requires_payment_method"
    }
  }
}
```

#### Test Case 3: Fraud Flag

```json
{
  "id": "evt_test_fraud_001",
  "object": "event",
  "type": "payment_intent.payment_failed",
  "data": {
    "object": {
      "id": "pi_test_fraud_001",
      "object": "payment_intent",
      "amount": 199900,
      "currency": "usd",
      "customer": "cus_test_003",
      "subscription": "sub_test_003",
      "receipt_email": "suspicious@example.com",
      "last_payment_error": {
        "code": "fraudulent",
        "message": "Your card was declined.",
        "decline_code": "fraudulent",
        "type": "card_error"
      },
      "status": "requires_payment_method"
    }
  }
}
```

#### Test Case 4: Generic Decline

```json
{
  "id": "evt_test_generic_001",
  "object": "event",
  "type": "payment_intent.payment_failed",
  "data": {
    "object": {
      "id": "pi_test_generic_001",
      "object": "payment_intent",
      "amount": 2999,
      "currency": "usd",
      "customer": "cus_test_004",
      "subscription": "sub_test_004",
      "receipt_email": "john.smith@example.com",
      "last_payment_error": {
        "code": "generic_decline",
        "message": "Your card was declined.",
        "decline_code": "generic_decline",
        "type": "card_error"
      },
      "status": "requires_payment_method"
    }
  }
}
```

#### Test Case 5: High-Value Payment

```json
{
  "id": "evt_test_high_value_001",
  "object": "event",
  "type": "payment_intent.payment_failed",
  "data": {
    "object": {
      "id": "pi_test_high_value_001",
      "object": "payment_intent",
      "amount": 500000,
      "currency": "usd",
      "customer": "cus_test_005",
      "subscription": "sub_test_005",
      "receipt_email": "enterprise@bigcorp.com",
      "last_payment_error": {
        "code": "insufficient_funds",
        "message": "Your card has insufficient funds.",
        "decline_code": "insufficient_funds",
        "type": "card_error"
      },
      "status": "requires_payment_method"
    }
  }
}
```

### Sample Database Records

Insert these directly into Supabase for testing retry logic:

```sql
-- Test payment ready for immediate retry
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
) VALUES (
  'pi_test_ready_retry_001',
  'cus_test_006',
  'sub_test_006',
  'ready.retry@example.com',
  'Ready Retry',
  4999,
  'usd',
  'expired_card',
  'Your card has expired.',
  'expired_card',
  0,
  1,
  NOW() - INTERVAL '1 hour',  -- Already due for retry
  'pending'
);

-- Test payment mid-retry cycle
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
) VALUES (
  'pi_test_mid_retry_001',
  'cus_test_007',
  'sub_test_007',
  'mid.retry@example.com',
  'Mid Retry',
  9999,
  'usd',
  'insufficient_funds',
  'Your card has insufficient funds.',
  'insufficient_funds',
  1,
  3,
  NOW() + INTERVAL '2 days',
  'pending'
);

-- Test payment that should not retry (fraud)
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
) VALUES (
  'pi_test_fraud_no_retry_001',
  'cus_test_008',
  'sub_test_008',
  'fraud.check@example.com',
  'Fraud Check',
  199900,
  'usd',
  'fraudulent',
  'Your card was declined.',
  'fraud_flag',
  0,
  0,
  NULL,
  'manual_review'
);

-- Test payment at max retries
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
) VALUES (
  'pi_test_max_retries_001',
  'cus_test_009',
  'sub_test_009',
  'max.retries@example.com',
  'Max Retries',
  2999,
  'usd',
  'expired_card',
  'Your card has expired.',
  'expired_card',
  1,
  1,
  NOW() - INTERVAL '1 hour',
  'pending'
);
```

---

## Part 2: Component Testing

Test each workflow individually before testing integration.

### Test 1: Webhook Receiver

**Objective:** Verify webhook receives and validates Stripe events

**Steps:**
1. Get webhook URL from n8n (from Webhook node)
2. Use cURL to send test webhook:

```bash
curl -X POST https://your-n8n-instance.com/webhook/stripe-payment-failed \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test_signature" \
  -d @tests/test-data/expired-card.json
```

**Expected Results:**
- [ ] Workflow executes successfully
- [ ] Returns 200 OK
- [ ] Data passed to next workflow
- [ ] No errors in execution log

**Common Issues:**
- Signature verification fails → Disable signature check for testing
- Workflow not found → Check webhook is activated
- JSON parse error → Verify JSON format is correct

---

### Test 2: Process Failed Payment

**Objective:** Verify payment categorization and retry scheduling

**Steps:**
1. Send all 4 test webhooks (expired, insufficient, fraud, generic)
2. Check Supabase `failed_payments` table
3. Verify each categorized correctly

**Expected Results:**

| Test Case | Expected Category | Max Retries | Next Retry |
|-----------|------------------|-------------|------------|
| Expired Card | `expired_card` | 1 | 24 hours |
| Insufficient Funds | `insufficient_funds` | 3 | 48 hours |
| Fraud Flag | `fraud_flag` | 0 | NULL |
| Generic | `other` | 1 | 72 hours |

**SQL to Verify:**
```sql
SELECT 
  failure_code,
  failure_category,
  max_retries,
  next_retry_at,
  status
FROM failed_payments
ORDER BY created_at DESC
LIMIT 10;
```

**Common Issues:**
- Wrong category → Check Switch node conditions
- Wrong retry timing → Check Set node calculations
- Not stored in DB → Check Supabase credentials

---

### Test 3: Send Email

**Objective:** Verify emails sent with correct templates

**Steps:**
1. Manually trigger "Send Email" workflow with test data:

```json
{
  "failed_payment_id": "test-uuid-001",
  "customer_email": "your-test-email@gmail.com",
  "customer_name": "Test Customer",
  "amount": 4999,
  "failure_category": "expired_card"
}
```

2. Check email inbox

**Expected Results:**
- [ ] Email received within 30 seconds
- [ ] Subject line matches failure type
- [ ] Personalized with customer name
- [ ] Amount displayed correctly
- [ ] CTA button/link present

**Test All Templates:**
- Expired card email
- Insufficient funds email  
- Generic failure email
- Fraud alert email (to internal team)

**Common Issues:**
- Email not received → Check SPAM folder
- Template not loading → Verify HTML in workflow
- Wrong email address → Check customer_email field

---

### Test 4: Retry Scheduler

**Objective:** Verify retry logic executes on schedule

**Steps:**
1. Insert test record with past `next_retry_at`:

```sql
-- This payment is overdue for retry
INSERT INTO failed_payments (
  stripe_payment_intent_id,
  stripe_customer_id,
  customer_email,
  amount,
  currency,
  failure_code,
  failure_category,
  retry_count,
  max_retries,
  next_retry_at,
  status
) VALUES (
  'pi_manual_test_001',
  'cus_manual_test_001',
  'your-test-email@gmail.com',
  4999,
  'usd',
  'expired_card',
  'expired_card',
  0,
  1,
  NOW() - INTERVAL '1 hour',
  'pending'
);
```

2. Manually trigger "Retry Scheduler" workflow
3. Check execution log
4. Verify Stripe API call attempted
5. Check `retry_attempts` table

**Expected Results:**
- [ ] Workflow finds overdue payment
- [ ] Attempts Stripe payment
- [ ] Creates record in `retry_attempts` table
- [ ] Updates `retry_count` in `failed_payments`
- [ ] Sets new `next_retry_at` if retry failed
- [ ] Updates status to `recovered` if successful

**SQL to Verify:**
```sql
SELECT 
  fp.stripe_payment_intent_id,
  fp.retry_count,
  fp.status,
  ra.attempted_at,
  ra.success
FROM failed_payments fp
LEFT JOIN retry_attempts ra ON fp.id = ra.failed_payment_id
WHERE fp.stripe_payment_intent_id = 'pi_manual_test_001';
```

**Common Issues:**
- No payment found → Check `next_retry_at` is in past
- Stripe error → Verify test mode enabled
- Not updating DB → Check Supabase credentials

---

### Test 5: Daily Report

**Objective:** Verify report generation and sending

**Steps:**
1. Ensure you have test data in database
2. Manually trigger "Daily Report" workflow
3. Check email inbox for report

**Expected Results:**
- [ ] Email received with yesterday's stats
- [ ] All metrics calculated correctly:
  - Total failures by category
  - Recovery rate by category
  - Amount at risk
  - Pending retries
- [ ] Alerts triggered if thresholds breached
- [ ] Slack notification sent (if configured)

**Test Scenarios:**

**Scenario A: Normal Operations**
- Recovery rate: 25%
- Amount at risk: $5,000
- Expected: Standard report, no alerts

**Scenario B: Low Recovery Rate**
- Recovery rate: 15%
- Amount at risk: $5,000
- Expected: Report + Low recovery rate alert

**Scenario C: High Amount at Risk**
- Recovery rate: 25%
- Amount at risk: $12,000
- Expected: Report + High risk amount alert

**Scenario D: Both Alerts**
- Recovery rate: 15%
- Amount at risk: $12,000
- Expected: Report + Both alerts

**SQL to Set Up Test Data:**
```sql
-- Yesterday's stats for testing
INSERT INTO recovery_stats (date, category, total_failures, total_recovered, total_permanent_failed, amount_at_risk, amount_recovered, amount_lost, recovery_rate)
VALUES 
  (CURRENT_DATE - 1, 'expired_card', 50, 10, 5, 150000, 50000, 25000, 20.00),
  (CURRENT_DATE - 1, 'insufficient_funds', 30, 8, 3, 90000, 24000, 9000, 26.67),
  (CURRENT_DATE - 1, 'fraud_flag', 5, 0, 5, 50000, 0, 50000, 0.00),
  (CURRENT_DATE - 1, 'other', 15, 4, 2, 45000, 12000, 6000, 26.67);
```

**Common Issues:**
- No data → Ensure yesterday's date has records
- Wrong calculations → Check SQL queries
- Email not sent → Check SMTP credentials
- Alerts not triggering → Verify threshold conditions

---

## Part 3: Integration Testing

Test workflows working together.

### Test 6: End-to-End Webhook to Retry

**Objective:** Full flow from webhook to retry attempt

**Timeline:** This test spans 24-48 hours

**Day 1 - Webhook Reception:**
1. Send expired card webhook
2. Verify stored in database
3. Verify email sent to customer
4. Note `next_retry_at` timestamp

**Day 2 - Retry Execution:**
1. Wait until `next_retry_at` time
2. Wait for retry scheduler to run (every 5 min)
3. Verify retry attempted
4. Check retry_attempts table
5. Verify status updated

**Expected Flow:**
```
Webhook → Store in DB → Send Email → Wait 24hrs → Retry Scheduler Runs → Attempt Payment → Update Status
```

**Verification Checklist:**
- [ ] Webhook received and processed
- [ ] Payment stored with category `expired_card`
- [ ] Email sent immediately
- [ ] `next_retry_at` set to 24 hours from now
- [ ] After 24 hours, retry scheduler picked it up
- [ ] Retry attempted (logged in retry_attempts)
- [ ] Status updated to `recovered` or `failed`

**SQL to Track:**
```sql
SELECT 
  fp.created_at as failure_time,
  fp.next_retry_at,
  fp.retry_count,
  fp.status,
  ra.attempted_at as retry_time,
  ra.success,
  fp.recovered_at
FROM failed_payments fp
LEFT JOIN retry_attempts ra ON fp.id = ra.failed_payment_id
WHERE fp.stripe_payment_intent_id = '[YOUR_TEST_PAYMENT_ID]'
ORDER BY ra.attempted_at DESC;
```

---

## Part 4: Edge Case Testing

Test unusual scenarios that might break the system.

### Edge Case 1: Duplicate Webhook

**Scenario:** Stripe sends same webhook twice

**Setup:**
1. Send same webhook JSON twice within 1 minute
2. Check database

**Expected Result:**
- [ ] First webhook processes normally
- [ ] Second webhook rejected (duplicate `stripe_payment_intent_id`)
- [ ] No duplicate records in database

**SQL to Verify:**
```sql
SELECT stripe_payment_intent_id, COUNT(*)
FROM failed_payments
GROUP BY stripe_payment_intent_id
HAVING COUNT(*) > 1;
```

Should return 0 rows.

---

### Edge Case 2: Payment Succeeds Before Retry

**Scenario:** Customer manually updates card before scheduled retry

**Setup:**
1. Create failed payment in database
2. Before retry time, manually update status:

```sql
UPDATE failed_payments
SET status = 'recovered', recovered_at = NOW()
WHERE stripe_payment_intent_id = 'pi_test_recovered_001';
```

3. Wait for retry scheduler to run

**Expected Result:**
- [ ] Retry scheduler skips this payment (status = recovered)
- [ ] No retry attempted
- [ ] No new record in retry_attempts

---

### Edge Case 3: Max Retries Reached

**Scenario:** Payment fails all retry attempts

**Setup:**
1. Create payment at max retries:

```sql
INSERT INTO failed_payments (
  stripe_payment_intent_id,
  stripe_customer_id,
  customer_email,
  amount,
  failure_category,
  retry_count,
  max_retries,
  next_retry_at,
  status
) VALUES (
  'pi_test_max_001',
  'cus_test_max_001',
  'test@example.com',
  4999,
  'expired_card',
  1,  -- Already at max
  1,  -- Max is 1
  NOW() - INTERVAL '1 hour',
  'pending'
);
```

2. Let retry scheduler run

**Expected Result:**
- [ ] Retry attempted one final time
- [ ] Status changed to `failed` (permanent)
- [ ] No further retries scheduled
- [ ] Final notification sent to customer

---

### Edge Case 4: Stripe API Error

**Scenario:** Stripe API is down or returns error

**Setup:**
1. Create test payment
2. Use invalid Stripe API key temporarily
3. Let retry scheduler run

**Expected Result:**
- [ ] Retry attempt logged as failed
- [ ] Error message captured
- [ ] Next retry still scheduled (don't give up on API errors)
- [ ] Alert sent if multiple consecutive API errors

---

### Edge Case 5: Missing Customer Data

**Scenario:** Webhook missing customer email

**Setup:**
Send webhook with `null` or empty email:

```json
{
  "data": {
    "object": {
      "id": "pi_test_no_email_001",
      "customer": "cus_test_no_email",
      "receipt_email": null,
      ...
    }
  }
}
```

**Expected Result:**
- [ ] Payment still stored
- [ ] Email field nullable (or fetch from Stripe customer object)
- [ ] Alert sent to admin about missing contact info
- [ ] Status set to `manual_review`

---

## Part 5: Load Testing

Test system under realistic load.

### Load Test 1: Burst of Failures

**Scenario:** 50 payments fail within 5 minutes

**Setup:**
1. Use script to send 50 webhooks rapidly:

```bash
for i in {1..50}
do
  curl -X POST https://your-n8n-instance.com/webhook/stripe-payment-failed \
    -H "Content-Type: application/json" \
    -d @tests/test-data/expired-card.json
  sleep 1
done
```

**Expected Results:**
- [ ] All 50 webhooks processed
- [ ] All 50 stored in database
- [ ] All 50 emails sent
- [ ] No workflow errors
- [ ] Average processing time < 2 seconds per webhook

---

### Load Test 2: Large Retry Batch

**Scenario:** 100 payments due for retry simultaneously

**Setup:**
1. Insert 100 test payments all due now:

```sql
INSERT INTO failed_payments (
  stripe_payment_intent_id,
  stripe_customer_id,
  customer_email,
  amount,
  failure_category,
  retry_count,
  max_retries,
  next_retry_at,
  status
)
SELECT 
  'pi_load_test_' || generate_series,
  'cus_load_test_' || generate_series,
  'test' || generate_series || '@example.com',
  4999,
  'expired_card',
  0,
  1,
  NOW() - INTERVAL '1 hour',
  'pending'
FROM generate_series(1, 100);
```

2. Let retry scheduler run

**Expected Results:**
- [ ] All 100 payments processed
- [ ] Retries attempted in batches (n8n processes 20 at a time by default)
- [ ] All attempts logged
- [ ] No timeout errors
- [ ] Processing completes within 5 minutes

---

## Testing Checklist Summary

### Before Production Launch

**Component Tests:**
- [ ] Webhook receiver working
- [ ] Payment categorization correct
- [ ] Retry scheduling accurate
- [ ] Emails sending properly
- [ ] Daily report generating

**Integration Tests:**
- [ ] Full webhook-to-retry flow working
- [ ] Multi-day retry cycles completing
- [ ] Status updates propagating

**Edge Cases:**
- [ ] Duplicate webhooks handled
- [ ] Max retries enforced
- [ ] API errors handled gracefully
- [ ] Missing data handled

**Load Tests:**
- [ ] 50+ simultaneous failures handled
- [ ] 100+ retry batch processed
- [ ] No performance degradation

**Monitoring:**
- [ ] Alerts configured and tested
- [ ] Daily reports arriving
- [ ] Error notifications working

---

## Automated Testing Script

Save this as `/tests/run-all-tests.sh`:

```bash
#!/bin/bash

echo "Starting Failed Payment Recovery Engine Tests..."

# Test 1: Expired Card
echo "Test 1: Expired Card Webhook"
curl -X POST $N8N_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d @tests/test-data/expired-card.json
sleep 2

# Test 2: Insufficient Funds
echo "Test 2: Insufficient Funds Webhook"
curl -X POST $N8N_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d @tests/test-data/insufficient-funds.json
sleep 2

# Test 3: Fraud Flag
echo "Test 3: Fraud Flag Webhook"
curl -X POST $N8N_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d @tests/test-data/fraud-flag.json
sleep 2

# Test 4: Generic Decline
echo "Test 4: Generic Decline Webhook"
curl -X POST $N8N_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d @tests/test-data/generic-decline.json

echo "Tests completed. Check n8n execution logs and Supabase database."
```

Make executable:
```bash
chmod +x tests/run-all-tests.sh
```

Run tests:
```bash
export N8N_WEBHOOK_URL="https://your-n8n-instance.com/webhook/stripe-payment-failed"
./tests/run-all-tests.sh
```

---

## What Success Looks Like

After completing all tests, you should see:

**In n8n:**
- All workflows showing green (successful executions)
- No error logs
- Execution times < 2 seconds per workflow

**In Supabase:**
- All test payments stored correctly
- Categories accurate
- Retry timing correct
- Status updates working

**In Email:**
- Test emails received
- Templates rendering correctly
- Personalization working

**In Reports:**
- Daily report accurate
- Alerts triggering at thresholds
- Metrics calculating correctly

---

## Next: Go to Production

Once all tests pass:

1. Switch to Production Stripe keys
2. Update webhook to production URL
3. Monitor closely for first week
4. Adjust retry strategies based on real data
5. Celebrate recovering lost revenue! 🎉

---

**Questions or Issues?**

1. Review [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Check [Installation Guide](INSTALLATION.md)
3. [Open an issue](https://github.com/yourusername/failed-payment-recovery-engine/issues)
