




🧪 Testing (Stripe Test Mode)

Use Stripe’s test cards:

Super prompt for building marke…

Expired card – 4000000000000069

Insufficient funds – 4000000000009995

Generic decline – 4000000000000002

Suggested test flow:

Create a test customer + subscription in Stripe

Attach a test card and trigger a payment failure

Confirm:

n8n receives webhook

Row created in failed_payments

Category + next retry time set correctly

Email sent via 3-Send-Payment-Failure-Email

Wait/trigger 4-Retry-Scheduler

Inspect retry_attempts and updated failed_payments

Verify recovery_dashboard and daily report workflow

More detailed test data lives in /docs/TEST_DATA.md.

📈 Example Impact

With modest volume (e.g., 200 failed payments/month at $50):

Super prompt for building marke…

Typical manual recovery: ~8% → 16 payments → $800 recovered

Engine-driven recovery: ~28% → 56 payments → $2,800 recovered

Incremental recovery: ~$2,000/month

If you’re a consultant, this is an off-the-shelf solution you can sell to SaaS teams and have it pay for itself in 2–3 months.
