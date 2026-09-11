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
- `anon` and `authenticated` have no grants on the automation tables; RLS remains enabled without permissive policies.
- Internal cron-to-worker calls use a generated secret stored in Supabase Vault. The database stores only its SHA-256 hash for verification.
- Edge Function public JWT verification is intentionally disabled only because the function performs custom service-to-service token authentication before accessing the queue.
- Missing, unapproved, stale or conflicting provider data fails closed.
- Human execution remains mandatory. Auto-trading is not introduced.

## Provider approval rule

An external provider is usable only when all are true:

1. required Edge Function secret exists;
2. provider registry `active=true`;
3. `readiness_status='READY'`;
4. `source_tier='A'`.

Twelve Data and Alpha Vantage are initially registered as `A_PENDING_VALIDATION`, inactive and `NOT_CONFIGURED`. Adding an API key alone cannot activate them.

## Price adapter

When both market providers are approved, the worker requests daily data from Twelve Data and Alpha Vantage, selects a common completed session on or before the requested session date, and computes:

`divergence = abs(price_A - price_B) / average(price_A, price_B)`

Production-compatible shadow acceptance requires divergence `<= 0.5%`. A larger difference returns `PRICE_CONFLICT` and does not promote the observation.

## SEC adapter

SEC is active Tier A and requires no API key. For each ticker the worker:

1. resolves ticker → CIK from SEC company tickers;
2. collects recent 10-K / 10-Q / 8-K / 20-F / 40-F / 6-K filing metadata;
3. collects SEC XBRL Company Facts;
4. compacts selected canonical financial tags rather than storing the complete multi-megabyte Company Facts payload;
5. fingerprints both payload classes so future runs can detect filing/fact deltas.

Current compact tag family includes revenue, net income, CFO, capex, cash, debt, SBC, diluted shares and diluted EPS where available.

## Consensus adapter

Alpha Vantage `EARNINGS_ESTIMATES` is wired but dormant until the provider is configured and promoted to approved Tier A. Missing approval returns a blocker; the worker never fabricates analyst consensus.

## Queue and retry semantics

Each candidate receives three jobs per shadow cycle:

- `SEC_SUBMISSIONS`
- `PRICE_PAIR`
- `CONSENSUS`

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

Worker v3 SEC/XBRL smoke test:

- ADBE SEC job PASS
- 30 recent relevant filings captured
- 11 compact Company Facts tags captured for the smoke sample
- RETRY 0 / DEAD_LETTER 0
- authoritative writes: **0**

Infrastructure regression: `tests/automation/test_auto_decision_refresh_shadow_v1.sql` → **11/11 PASS** against live production schema.

## Cron schedule

- Enqueue: `35 21 * * 1-5` UTC. This deliberately wakes after the regular US close across DST regimes; provider/session validation remains required before a market price can pass.
- Worker: `*/5 * * * *`.

The weekday schedule does not itself prove that a date is a valid market session. The market-data adapter must provide a common completed session; otherwise price collection blocks.

## Current cutover gate

`PRODUCTION_CUTOVER = BLOCKED_UNTIL_PROVIDER_KEYS_AND_SHADOW_VALIDATION`

Before any promotion from Shadow to production:

1. configure Twelve Data and Alpha Vantage secrets through Supabase secrets management;
2. validate provider session/date semantics, adjusted/unadjusted close semantics and rate limits;
3. promote provider registry rows from `A_PENDING_VALIDATION` to Tier A / READY only after deterministic tests pass;
4. run multiple completed US market sessions in Shadow mode;
5. compare shadow output with independently verified production evidence;
6. add deterministic normalization/material-event/Decision Refresh regressions;
7. only then design an explicit production cutover migration.

No automatic production decision write is authorized by this document.
