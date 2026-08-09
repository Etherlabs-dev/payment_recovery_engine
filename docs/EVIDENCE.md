# Evidence and Claim Policy

This repository is a public reference implementation for payment-failure recovery. Claims should be traceable to code, automated tests, reproducible simulations, or production evidence.

## Evidence classes

| Label | Meaning |
|---|---|
| **Implemented** | Capability exists in repository artifacts |
| **Tested** | Covered by executable automated tests |
| **Synthetic / Demonstration** | Proven only with test fixtures or generated events |
| **Modeled Outcome** | Business impact derived from assumptions |
| **Production** | Verified live-system evidence |
| **Client Outcome** | Real customer result with evidence/permission |

## Current repository status

**Reference Implementation / Validation Candidate**

### Implemented
- webhook-driven recovery workflow design;
- payment-failure categorization flow;
- retry scheduling concepts;
- Supabase/PostgreSQL persistence artifacts;
- email templates;
- operational reporting/alerting workflow artifacts;
- test-mode/sample webhook fixtures.

### Not established by this repository alone
- 28–35% recovery rate;
- 3× recovery improvement;
- $12K–15K monthly recovered revenue;
- 96% reduction in manual effort;
- production response-time or availability claims.

Any future recovery benchmark should state:
- number of simulated failures;
- decline-code distribution;
- retry policy;
- control/baseline policy;
- recovered vs unrecovered cases;
- duplicate/replay scenarios;
- notification count;
- time horizon;
- whether recovery was simulated or observed in production.

Do not convert modeled or synthetic outcomes into client-result language.