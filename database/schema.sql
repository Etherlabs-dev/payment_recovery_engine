🗄 Supabase Schema

Run this SQL in your Supabase project.

Super prompt for building marke…

<details> <summary><code>failed_payments</code></summary>
CREATE TABLE failed_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Stripe data
  stripe_payment_intent_id TEXT UNIQUE NOT NULL,
  stripe_customer_id TEXT NOT NULL,
  stripe_subscription_id TEXT,

  -- Customer info
  customer_email TEXT NOT NULL,
  customer_name TEXT,

  -- Payment details
  amount INTEGER NOT NULL, -- in cents
  currency TEXT DEFAULT 'usd',

  -- Failure details
  failure_code TEXT NOT NULL,
  failure_message TEXT,
  failure_category TEXT NOT NULL, -- 'expired_card', 'insufficient_funds', 'fraud_flag', 'other'

  -- Retry tracking
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER NOT NULL,
  next_retry_at TIMESTAMPTZ,

  -- Status
  status TEXT DEFAULT 'pending', -- 'pending', 'retrying', 'recovered', 'failed', 'manual_review'
  recovered_at TIMESTAMPTZ,

  -- Metadata
  metadata JSONB
);

CREATE INDEX idx_failed_payments_status ON failed_payments(status);
CREATE INDEX idx_failed_payments_next_retry
  ON failed_payments(next_retry_at) WHERE status = 'pending';
CREATE INDEX idx_failed_payments_customer
  ON failed_payments(stripe_customer_id);

</details> <details> <summary><code>retry_attempts</code></summary>
CREATE TABLE retry_attempts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  failed_payment_id UUID REFERENCES failed_payments(id),

  retry_number INTEGER NOT NULL,
  attempted_at TIMESTAMPTZ DEFAULT NOW(),

  success BOOLEAN,
  stripe_charge_id TEXT,
  failure_reason TEXT,

  metadata JSONB
);

CREATE INDEX idx_retry_attempts_payment
  ON retry_attempts(failed_payment_id);

</details> <details> <summary><code>recovery_stats</code></summary>
CREATE TABLE recovery_stats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  date DATE DEFAULT CURRENT_DATE,

  category TEXT NOT NULL,

  total_failures INTEGER DEFAULT 0,
  total_recovered INTEGER DEFAULT 0,
  total_permanent_failed INTEGER DEFAULT 0,

  amount_at_risk INTEGER DEFAULT 0,
  amount_recovered INTEGER DEFAULT 0,
  amount_lost INTEGER DEFAULT 0,

  recovery_rate DECIMAL(5,2),

  UNIQUE(date, category)
);

</details> <details> <summary>RLS Policies (Service Role)</summary>
ALTER TABLE failed_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE retry_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE recovery_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all for service role" ON failed_payments
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Enable all for service role" ON retry_attempts
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Enable all for service role" ON recovery_stats
  FOR ALL USING (auth.role() = 'service_role');

</details>
📊 Recovery Dashboard View (Optional but Recommended)
CREATE VIEW recovery_dashboard AS
SELECT
  DATE_TRUNC('day', created_at) AS date,
  failure_category,
  COUNT(*) AS total_failures,
  SUM(CASE WHEN status = 'recovered' THEN 1 ELSE 0 END) AS total_recovered,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS total_failed,
  SUM(amount) FILTER (WHERE status IN ('pending', 'retrying')) AS amount_at_risk,
  SUM(amount) FILTER (WHERE status = 'recovered') AS amount_recovered,
  SUM(amount) FILTER (WHERE status = 'failed') AS amount_lost,
  ROUND(
    (SUM(CASE WHEN status = 'recovered' THEN 1 ELSE 0 END)::DECIMAL / COUNT(*)) * 100,
    2
  ) AS recovery_rate_percentage
FROM failed_payments
GROUP BY DATE_TRUNC('day', created_at), failure_category
ORDER BY date DESC, failure_category;
