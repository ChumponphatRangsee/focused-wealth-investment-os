# 08 — Auto Decision Refresh v1 — Shadow Automation

Status: **SHADOW ACTIVE / FAIL-CLOSED**  
Activation date: **2026-09-11 Asia/Bangkok**  
Contract: **FWIOS-CONTRACT-0.87.11**  
Execution: **HUMAN EXECUTION ONLY**

## Purpose
Move routine Decision Refresh initiation and machine-readable evidence collection out of ChatGPT-triggered execution and into Supabase-managed automation without weakening production gates.

Shadow mode is deliberately non-authoritative. It may collect evidence and exercise adapters, but it cannot write production Decision Snapshots, Opportunity Ranking, portfolio state, broker orders or holdings.

## Runtime architecture

```text
pg_cron
  ├─ weekday enqueue: 21:35 UTC
  └─ worker wake-up: every 5 minutes
        ↓
fwios.start_decision_refresh_shadow()
        ↓
PGMQ queue: fwios_decision_refresh
        ↓
decision-refresh-worker-v1 Edge Function
        ↓
┌────────────────────────────────────────────┐
│ SEC EDGAR / data.sec.gov                  │ READY
│ Twelve Data market-price adapter          │ NOT CONFIGURED / NOT APPROVED
│ Alpha Vantage price + consensus adapter   │ NOT CONFIGURED / NOT APPROVED
└────────────────────────────────────────────┘
        ↓
fwios.decision_refresh_shadow_evidence
        ↓
shadow validation only
```

## Safety boundary
- `fwios.decision_refresh_runs.mode='SHADOW'` is paired with a database CHECK that forbids `authoritative_write=true`.
- Shadow evidence is isolated in `fwios.decision_refresh_shadow_evidence`.
- `anon` and `authenticated` have no grants on automation tables; RLS remains enabled without permissive policies.
- Internal cron-to-worker calls use a generated secret stored in Supabase Vault. The database stores only its SHA-256 hash for verification.
- Edge Function public JWT verification is intentionally disabled only because the function performs custom service-to-service token authentication before queue access.
- Missing, unapproved, stale or conflicting provider data fails closed.
- Human execution remains mandatory. Auto-trading is not introduced.

## Provider approval rule
An external provider is usable only when all are true:
1. required secret exists;
2. provider registry `active=true`;
3. `readiness_status='READY'`;
4. `source_tier='A'`.

Twelve Data and Alpha Vantage remain `A_PENDING_VALIDATION`, inactive and `NOT_CONFIGURED`. Adding an API key alone cannot activate them.

## Provider Validation v1
`fwios.decision_refresh_provider_validation_runs` records deterministic validation evidence. `fwios.decision_refresh_provider_promotion_gate(provider)` returns whether a provider is eligible for promotion without mutating the provider registry.

Required checks:
- documentation contract;
- live connectivity;
- response schema;
- session semantics;
- adjustment semantics;
- rate-limit behavior;
- at least 3 distinct completed-session price crosschecks;
- Alpha Vantage additionally requires consensus schema and freshness checks.

Current live regression: `tests/automation/test_decision_refresh_provider_validation_v1.sql` → **10/10 PASS**.

## Price semantics
Alpha Vantage `TIME_SERIES_DAILY` is treated as raw as-traded daily OHLC. Twelve Data `/time_series` is explicitly requested with `adjust=none`; this avoids comparing Twelve Data's default split-adjusted series with Alpha Vantage raw closes.

Worker v5 also bounds Twelve Data requests to the requested session with `end_date` while still locally rejecting any returned date later than the requested session. Both providers must share a completed session and divergence must be `<=0.5%`.

`divergence = abs(price_A - price_B) / average(price_A, price_B)`

A larger difference returns `PRICE_CONFLICT` and cannot promote the observation.

## SEC adapter
SEC is active Tier A and requires no API key. For each ticker the worker:
1. resolves ticker → CIK from SEC company tickers;
2. collects recent 10-K / 10-Q / 8-K / 20-F / 40-F / 6-K filing metadata;
3. collects SEC XBRL Company Facts;
4. compacts selected canonical financial tags rather than storing the complete multi-megabyte payload;
5. fingerprints both payload classes so future runs can detect filing/fact deltas.

Current compact tag family includes revenue, net income, CFO, capex, cash, debt, SBC, diluted shares and diluted EPS where available.

## Consensus adapter
Alpha Vantage `EARNINGS_ESTIMATES` is wired but dormant until the provider is configured and promoted to approved Tier A. Missing approval returns a blocker; the worker never fabricates analyst consensus.

## Queue and retry semantics
Each candidate receives three jobs per shadow cycle: `SEC_SUBMISSIONS`, `PRICE_PAIR`, `CONSENSUS`.

Transient exceptions use `RETRY` up to `max_attempts`; exhausted failures become `DEAD_LETTER`. Deterministic missing-provider conditions become `BLOCKED` immediately rather than wasting retries.

## First acceptance run
Run: `44aab470-c45d-4e73-9a05-85dada616433`
- 27 candidates
- 81 jobs
- 27 SEC jobs PASS
- 54 Price/Consensus jobs BLOCKED by unconfigured provider gate
- 0 RETRY after queue-ack patch
- 0 DEAD_LETTER
- authoritative writes: **0**

Worker SEC/XBRL smoke: ADBE PASS, 30 recent relevant filings, 11 compact Company Facts tags, RETRY 0, DEAD_LETTER 0.

Infrastructure regression: `tests/automation/test_auto_decision_refresh_shadow_v1.sql` → **11/11 PASS**.
Provider validation regression: `tests/automation/test_decision_refresh_provider_validation_v1.sql` → **10/10 PASS**.

## Cron schedule
- Enqueue: `35 21 * * 1-5` UTC.
- Worker: `*/5 * * * *`.

The weekday schedule does not itself prove a valid market session. The market-data adapter must provide a common completed session; otherwise price collection blocks.

## Current cutover gate
`PRODUCTION_CUTOVER = BLOCKED_UNTIL_PROVIDER_KEYS_AND_SHADOW_VALIDATION`

Before promotion from Shadow to production:
1. add `TWELVE_DATA_API_KEY` and `ALPHA_VANTAGE_API_KEY` through Supabase secrets management;
2. execute live connectivity/schema/session/adjustment/rate-limit tests;
3. complete at least 3 completed-session price crosschecks;
4. validate Alpha Vantage consensus schema and freshness;
5. only after `decision_refresh_provider_promotion_gate()` returns eligible may a separate explicit change promote the provider to Tier A / READY;
6. continue several completed market sessions in Shadow mode and compare against independently verified evidence;
7. only then design an explicit production cutover migration.

No automatic production decision write is authorized by this document.
