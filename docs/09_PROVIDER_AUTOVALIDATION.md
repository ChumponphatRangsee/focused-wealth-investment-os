# 09 — Decision Refresh Provider Auto-Validation

Status: **SHADOW ACTIVE / FAIL-CLOSED**  
Activation: **2026-09-11 Asia/Bangkok**  
Execution boundary: **HUMAN EXECUTION ONLY**

## Purpose

Complete the provider onboarding loop without requiring ChatGPT to trigger validation. Once the required API keys appear in Supabase Vault, the system validates market-data and consensus providers automatically and can promote them to `Tier A / READY` only after fresh deterministic evidence passes.

## Runtime

```text
Supabase Vault keys
      ↓
pg_cron — minute 17 every hour
      ↓
decision-refresh-provider-validator-v1
      ↓
provider validation evidence
      ↓
decision_refresh_provider_promotion_gate()
      ↓
apply_decision_refresh_provider_promotion()
      ↓
Tier A / READY only if every required gate passes
```

The validator uses `AAPL` for price/session crosschecks and `IBM` for Alpha Vantage earnings-estimate schema/freshness validation.

## Safety gates

Provider promotion requires:
- secret present;
- documentation contract PASS;
- fresh live connectivity PASS;
- fresh response-schema PASS;
- fresh session-semantics PASS;
- fresh adjustment-semantics PASS;
- fresh rate-limit check PASS;
- at least three distinct price crosscheck sessions in the last 14 days;
- for Alpha Vantage, consensus schema and consensus freshness PASS.

Operational validation evidence expires after seven days. Old PASS results cannot keep a provider eligible forever.

## Price semantics

Twelve Data is called with `adjust=none`; Alpha Vantage uses raw `TIME_SERIES_DAILY`. The validator requires three common completed sessions and <=0.5% close-price divergence for each session.

## Failure behavior

- Missing keys → `BLOCKED_KEYS_MISSING`; no provider promotion.
- Provider error / entitlement problem / rate limit / schema drift → validation FAIL and provider remains non-authoritative.
- Repeated cron wake-ups observe a cooldown after live validation attempts to avoid unnecessary API use.
- Provider auto-promotion changes only provider readiness used by Shadow Decision Refresh. It does not authorize production Decision Snapshot writes, ranking mutation, portfolio mutation, broker orders, or auto-trading.

## Current state

At implementation time the Vault has neither `TWELVE_DATA_API_KEY` nor `ALPHA_VANTAGE_API_KEY`. Smoke validation therefore correctly returns `BLOCKED_KEYS_MISSING` with HTTP 200. Database auto-validation regression is **10/10 PASS**.
