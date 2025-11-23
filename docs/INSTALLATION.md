# Installation & Configuration Guide

## Complete Setup Instructions for Failed Payment Recovery Engine

This guide will walk you through setting up the Failed Payment Recovery Engine from scratch. Expected time: 30-45 minutes.

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] **n8n instance** (v1.0 or higher)
  - Self-hosted OR n8n Cloud subscription
  - Admin access to install workflows
  
- [ ] **Supabase account** (free tier works)
  - New project created
  - API keys accessible
  
- [ ] **Stripe account**
  - Test mode enabled
  - API keys ready
  
- [ ] **Email service**
  - Gmail with app password OR
  - SendGrid account OR
  - Any SMTP service

- [ ] **Slack workspace** (optional)
  - For real-time alerts
  - Incoming webhook configured

---

## Part 1: Supabase Database Setup (10-15 minutes)

### Step 1: Create Supabase Project

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Click "New Project"
3. Fill in project details:
   - Name: `payment-recovery-engine`
   - Database Password: (save this securely)
   - Region: Choose closest to your location
4. Click "Create new project"
5. Wait 2-3 minutes for provisioning

### Step 2: Run Database Schema

1. In your Supabase project, go to **SQL Editor**
2. Copy the entire contents of `/database/schema.sql`
3. Paste into SQL Editor
4. Click "Run" (bottom right)
5. Verify success: You should see "Success. No rows returned"

### Step 3: Verify Tables Created

Go to **Table Editor** and confirm these tables exist:
- `failed_payments`
- `retry_attempts`
- `recovery_stats`

### Step 4: Get API Credentials

1. Go to **Settings** → **API**
2. Copy and save these values:
   - **Project URL:** `https://xxxxx.supabase.co`
   - **anon public key:** `eyJhbG...` (for client-side, not needed here)
   - **service_role key:** `eyJhbG...` (KEEP SECRET - use this in n8n)

### Step 5: Enable Row Level Security (Already done in schema)

The schema automatically enables RLS with service role access. Verify:
1. Go to **Table Editor**
2. Click on `failed_payments` table
3. Click "View Policies" (should see policy for service role)

---

## Part 2: n8n Credentials Setup (5-10 minutes)

### Step 1: Add Supabase Credential

1. In n8n, go to **Credentials** → **New**
2. Search for "Supabase"
3. Fill in:
   - **Host:** Your Supabase project URL (without https://)
   - **Service Role Secret:** Your service_role key from Supabase
4. Click "Save"
5. Name it: "Supabase Payment Recovery"

### Step 2: Add Stripe Credential

1. Go to **Credentials** → **New**
2. Search for "Stripe API"
3. Fill in:
   - **API Key:** Your Stripe Secret Key
     - Get from: Stripe Dashboard → Developers → API keys
     - Use **Test Mode** key: `sk_test_...`
4. Click "Save"
5. Name it: "Stripe API"

### Step 3: Add Email Credential (Gmail Example)

1. Go to **Credentials** → **New**
2. Search for "SMTP"
3. Fill in:
   - **Host:** `smtp.gmail.com`
   - **Port:** `587`
   - **User:** `your-email@gmail.com`
   - **Password:** App-specific password
     - Generate from: Google Account → Security → 2-Step Verification → App passwords
   - **SSL/TLS:** Enabled
4. Click "Save"
5. Name it: "Gmail SMTP"

**Alternative for SendGrid:**
- Host: `smtp.sendgrid.net`
- Port: `587`
- User: `apikey`
- Password: Your SendGrid API key

### Step 4: Add Slack Credential (Optional)

1. Create Slack incoming webhook:
   - Go to [Slack API](https://api.slack.com/apps)
   - Create new app → "From scratch"
   - Enable "Incoming Webhooks"
   - Add new webhook to workspace
   - Copy webhook URL
2. In n8n, go to **Credentials** → **New**
3. Search for "Slack"
4. Choose "Incoming Webhook"
5. Paste webhook URL
6. Click "Save"
7. Name it: "Slack Alerts"

---

## Part 3: Environment Variables Setup (5 minutes)

### In n8n Cloud:

1. Go to **Settings** → **Environments**
2. Add these variables:

```bash
STRIPE_WEBHOOK_SECRET=whsec_xxxxx  # Will get this in next section
STRIPE_SECRET_KEY=sk_test_xxxxx     # Your Stripe secret key
N8N_HOST=https://your-instance.app.n8n.cloud  # Your n8n URL
REPORT_EMAIL=your-email@company.com
SLACK_ALERT_CHANNEL=#payment-alerts  # Optional
DASHBOARD_URL=https://your-dashboard.com  # Optional
```

### In Self-Hosted n8n:

Add to your `.env` file or environment configuration:

```bash
STRIPE_WEBHOOK_SECRET=whsec_xxxxx
STRIPE_SECRET_KEY=sk_test_xxxxx
N8N_HOST=https://your-n8n-domain.com
REPORT_EMAIL=your-email@company.com
SLACK_ALERT_CHANNEL=#payment-alerts
DASHBOARD_URL=https://your-dashboard.com
```

Restart n8n after adding variables.

---

## Part 4: Import n8n Workflows (10-15 minutes)

### Import Order (Important!)

Import workflows in this exact order to avoid dependency issues:

#### 1. Import Webhook Receiver

1. In n8n, go to **Workflows** → **Add workflow**
2. Click three dots (⋮) → **Import from File**
3. Select `n8n-workflows/1-webhook-receiver.json`
4. Update credentials:
   - Stripe API → Select "Stripe API" credential you created
5. **Activate** the workflow
6. Copy the webhook URL (will need this for Stripe)

#### 2. Import Process Failed Payment

1. **Add workflow** → **Import from File**
2. Select `n8n-workflows/2-process-failed-payment.json`
3. Update credentials:
   - Stripe API → "Stripe API"
   - Supabase → "Supabase Payment Recovery"
4. Review the "Set Retry Strategy" node to customize timing if needed
5. **Activate** the workflow

#### 3. Import Send Email

1. **Add workflow** → **Import from File**
2. Select `n8n-workflows/3-send-email.json`
3. Update credentials:
   - Email Send → "Gmail SMTP" (or your email service)
4. Customize email templates in "Format Email" nodes if desired
5. **Activate** the workflow

#### 4. Import Retry Scheduler

1. **Add workflow** → **Import from File**
2. Select `n8n-workflows/4-retry-scheduler.json`
3. Update credentials:
   - Supabase → "Supabase Payment Recovery"
   - Stripe API → "Stripe API"
4. **Activate** the workflow
5. Schedule will run every 5 minutes automatically

#### 5. Import Daily Report

1. **Add workflow** → **Import from File**
2. Select `n8n-workflows/5-daily-report.json`
3. Update credentials:
   - Supabase → "Supabase Payment Recovery"
   - Email Send → "Gmail SMTP"
   - Slack (optional) → "Slack Alerts"
4. Verify schedule: Should run daily at 9:00 AM
5. **Activate** the workflow

---

## Part 5: Stripe Webhook Configuration (5 minutes)

### Step 1: Get Webhook URL

From your **Webhook Receiver** workflow:
1. Click on the Webhook node
2. Copy the "Test URL" or "Production URL"
3. Should look like: `https://your-n8n-instance.com/webhook/stripe-payment-failed`

### Step 2: Create Webhook in Stripe

1. Go to [Stripe Dashboard](https://dashboard.stripe.com)
2. Navigate to **Developers** → **Webhooks**
3. Click **Add endpoint**
4. Fill in:
   - **Endpoint URL:** Your n8n webhook URL
   - **Description:** Payment Failure Recovery System
   - **Events to send:** Select these 3 events:
     - `payment_intent.payment_failed`
     - `invoice.payment_failed`
     - `charge.failed`
5. Click **Add endpoint**

### Step 3: Get Signing Secret

1. After creating webhook, click on it
2. Under "Signing secret," click **Reveal**
3. Copy the secret (starts with `whsec_`)
4. Add to n8n environment variables:
   ```bash
   STRIPE_WEBHOOK_SECRET=whsec_xxxxx
   ```
5. Restart n8n if self-hosted

### Step 4: Test Webhook

1. In Stripe webhook page, click **Send test webhook**
2. Choose `payment_intent.payment_failed`
3. Click **Send test webhook**
4. Go to n8n → Check **Webhook Receiver** workflow executions
5. Should see successful execution

---

## Part 6: Initial Testing (10 minutes)

### Test 1: Webhook Reception

1. Use Stripe CLI or Dashboard to send test webhook
2. Check n8n workflow execution log
3. Verify data appears in Supabase `failed_payments` table

**Expected result:**
- Webhook received successfully
- Data stored in Supabase
- Email sent to test email address

### Test 2: Retry Scheduler

1. Wait 5 minutes (or manually trigger the workflow)
2. Check n8n **Retry Scheduler** executions
3. Should process any payments due for retry

**Expected result:**
- Scheduler runs without errors
- Retries attempted on time
- `retry_attempts` table updated

### Test 3: Daily Report

1. Manually trigger **Daily Report** workflow
2. Check email inbox
3. Should receive formatted report

**Expected result:**
- Email received with yesterday's statistics
- No errors in workflow

### Test 4: End-to-End Test

**Simulate a real failure:**

1. In Stripe Test Mode, create a test payment with expired card:
   - Card number: `4000000000000069`
   - Any future date
   - Any CVC

2. The payment will fail automatically

3. **Verify the flow:**
   - [ ] Webhook received (check n8n logs)
   - [ ] Payment stored in Supabase
   - [ ] Email sent to customer
   - [ ] Retry scheduled for 24 hours
   - [ ] After 24 hours, retry attempted
   - [ ] Final status updated

---

## Configuration Options

### Customize Retry Strategies

Edit `2-process-failed-payment.json` workflow:

**Expired Card Strategy:**
```javascript
{
  "failure_category": "expired_card",
  "max_retries": 1,
  "retry_schedule": [
    { "retry_number": 1, "delay_hours": 24 }  // Change 24 to your preference
  ]
}
```

**Insufficient Funds Strategy:**
```javascript
{
  "failure_category": "insufficient_funds",
  "max_retries": 3,
  "retry_schedule": [
    { "retry_number": 1, "delay_hours": 48 },   // 2 days
    { "retry_number": 2, "delay_hours": 120 },  // 5 days total
    { "retry_number": 3, "delay_hours": 168 }   // 7 days total
  ]
}
```

### Customize Email Templates

Edit `3-send-email.json` workflow → "Format Email" nodes:

**Expired Card Email:**
```html
Subject: Update Your Payment Method

Hi {{ $json.customer_name }},

We weren't able to process your recent payment because your card has expired.

Please update your payment method to continue your subscription.

[Update Payment Method]

Thanks,
Your Company Team
```

**Insufficient Funds Email:**
```html
Subject: Payment Notification

Hi {{ $json.customer_name }},

Your recent payment couldn't be processed due to insufficient funds.

We'll automatically try again in a few days. No action needed unless you'd like to update your payment method.

[View Account]

Thanks,
Your Company Team
```

### Customize Alert Thresholds

Edit `5-daily-report.json` workflow:

**Recovery Rate Alert:**
```javascript
// Alert if recovery rate < 20%
"value1": "={{ $json.metrics.overallRecoveryRate }}",
"operation": "smaller",
"value2": 20  // Change threshold here
```

**Amount at Risk Alert:**
```javascript
// Alert if amount > $10,000
"value1": "={{ parseFloat($json.metrics.amountAtRisk) }}",
"operation": "larger",
"value2": 10000  // Change threshold here
```

---

## Troubleshooting

### Webhook Not Receiving Data

**Symptoms:** Webhook executions not appearing in n8n

**Fixes:**
1. Verify webhook URL is correct in Stripe
2. Check n8n firewall allows incoming requests
3. Verify webhook is activated in n8n
4. Test with Stripe CLI:
   ```bash
   stripe trigger payment_intent.payment_failed
   ```

### Signature Verification Failed

**Symptoms:** Webhook receives data but signature check fails

**Fixes:**
1. Verify `STRIPE_WEBHOOK_SECRET` matches Stripe webhook signing secret
2. Check n8n can access environment variables
3. Restart n8n after updating environment variables

### Database Connection Failed

**Symptoms:** "Connection to Supabase failed"

**Fixes:**
1. Verify Supabase URL is correct (no `https://`)
2. Check service_role key is correct
3. Verify Supabase project is not paused (free tier)
4. Check network can reach Supabase

### Emails Not Sending

**Symptoms:** Email nodes fail to send

**Fixes:**
1. Verify SMTP credentials
2. Check email service allows SMTP (Gmail requires app password)
3. Verify port 587 is not blocked
4. Test email credential in n8n credential manager

### Retries Not Running

**Symptoms:** Payments not retrying at scheduled time

**Fixes:**
1. Verify **Retry Scheduler** workflow is activated
2. Check schedule is set to 5-minute intervals
3. Verify `next_retry_at` is populated in database
4. Check n8n has correct timezone configured

---

## Production Checklist

Before going live:

- [ ] All workflows tested with test data
- [ ] Stripe webhook using production keys
- [ ] Email templates reviewed and approved
- [ ] Alert thresholds configured for your business
- [ ] Daily report recipient confirmed
- [ ] Backup database configured in Supabase
- [ ] Monitoring set up for workflow failures
- [ ] Customer support informed about new email templates
- [ ] Legal/compliance reviewed email templates
- [ ] Disaster recovery plan documented

---

## Maintenance

### Daily Tasks
- Review daily report email
- Check Slack alerts (if configured)
- Verify workflows running without errors

### Weekly Tasks
- Review recovery rates by category
- Check for unusual patterns
- Verify Supabase database size (free tier has limits)

### Monthly Tasks
- Analyze trends in failure types
- Update retry strategies if needed
- Review and update email templates
- Check Stripe and Supabase billing

---

## Next Steps

After successful setup:

1. **Monitor for 7 days** - Watch workflows in test mode
2. **Adjust retry strategies** - Based on your actual data
3. **Customize templates** - Make emails match your brand
4. **Set up dashboard** - Build reporting dashboard in your BI tool
5. **Go live** - Switch to production Stripe keys

---

## Support

If you encounter issues:

1. Check [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review [Testing Guide](TESTING.md)
3. [Open an issue](https://github.com/yourusername/payment-recovery-engine/issues)
4. Email: ethercess@proton.me

---

**Installation Complete! 🎉**

Your Failed Payment Recovery Engine is now ready to recover lost revenue automatically.
