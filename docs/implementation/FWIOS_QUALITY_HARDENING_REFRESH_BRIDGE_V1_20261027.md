# FWIOS Quality Hardening Refresh Bridge v1 — Production Receipt

Date: 2026-10-27  
Contract target: `FWIOS-CONTRACT-0.87.22`  
Live migration: `20261027023035 quality_hardening_refresh_bridge_v1`

## Problem

ACN, EOG and NFLX valuation v2 production cutover completed successfully, but downstream Quality / Durability Hardening still referenced stale v1 valuation runs and legacy market-price/mispricing snapshots. NFLX had no production hardening snapshot at all.

The resulting failure was an integration/lineage gap, not a reason to loosen `POL-QUALITY-HARDENING-V1`.

## Scope

Additive bridge only:

```
current production valuation
        +
accepted canonical daily close
        +
valid prior production hardening evidence
        ↓
compatibility market-price snapshot
        ↓
current mispricing snapshot
        ↓
recomputed Quality Hardening snapshot
        ↓
research readiness / decision path
```

No dashboard was added. The existing Google Sheet remains the user-facing surface.

## Policy

New deterministic policy: `POL-QUALITY-HARDENING-REFRESH-V1`.

Functions:

- `fwios.preview_quality_hardening_refresh_v1(ticker)`
- `fwios.apply_quality_hardening_refresh_v1(ticker, human_authorized)`

Both functions are service-role-only. Preview is non-mutating. Apply requires explicit human authorization and is idempotent.

The bridge does not change any existing hardening thresholds. It consumes the active readiness policy for accepted price verification/provenance and freshness, and consumes the active hardening/mispricing policies for gate calculation.

## Evidence carry-forward rules

Prior hardening evidence may only be carried forward when the prior snapshot is within the readiness hardening freshness window. The bridge never upgrades Business Durability or Owner Earnings beyond the prior evidence-supported state.

- Missing or structurally incomplete prior evidence => `BLOCKED`.
- Shadow SEC evidence is not allowed to directly create a production PASS.
- Value Trap is recomputed against current mispricing.
- Valuation Robustness is recomputed from current production Fair Value and current accepted canonical price.

## Canonical price compatibility

The bridge does not fetch a second market price. It creates the minimum compatibility records required by the legacy mispricing schema from the already-canonical `market_daily_closes` observation and verification lineage.

For the 2026-10-26 refresh, the accepted daily closes were:

| Ticker | Session | Price | Verification | Provenance |
| --- | --- | ---: | --- | --- |
| ACN | 2026-10-26 | 247.27 | PRIMARY_ONLY | PASS |
| EOG | 2026-10-26 | 163.685 | PRIMARY_ONLY | PASS |
| NFLX | 2026-10-26 | 63.895 | PRIMARY_ONLY | PASS |

`PRIMARY_ONLY` is already an accepted status under `POL-RESEARCH-READINESS-V1`; the bridge does not weaken that policy.

## Production apply result

Explicit owner authorization was provided in the active implementation session.

| Ticker | Production valuation | New hardening | Result |
| --- | --- | --- | --- |
| ACN | `VAL-PROD-ACN-ITSERV-V2-20261026` | `HARD-QHR-ACN-20261026-7cf9191efa86` | REVIEW |
| EOG | `VAL-PROD-EOG-EP-V2-20261026` | `HARD-QHR-EOG-20261026-ab84bad8c12f` | FAIL |
| NFLX | `VAL-PROD-NFLX-STREAM-V2-20261026` | `HARD-QHR-NFLX-20261026-1a89fb3773a5` | BLOCKED |

All three now have hardening lineage aligned to the current v2 production valuation. None became `investment_review_ready`.

Current price-sensitive outcomes:

- ACN robustness = REVIEW; bear upside approximately -30.45%.
- EOG robustness = FAIL; bear upside approximately -73.39%.
- NFLX robustness = REVIEW, while Business Durability and Owner Earnings remain BLOCKED because production hardening evidence is missing.

All three current mispricing gates are `FAIL - INSUFFICIENT MISPRICING`.

## Idempotency and access

- Apply without authorization => `BLOCKED / HUMAN_AUTHORIZATION_REQUIRED`.
- Exact repeat apply after successful refresh => `NOOP_ALREADY_REFRESHED`.
- `anon` and `authenticated` cannot execute preview/apply.
- `service_role` can execute both.

## Regression

Bridge-specific live SQL acceptance: **8/8 PASS**.

Baseline Quality Hardening regression recheck: **10/11 PASS**. The single failure is the existing `QH-08 PINS production bucket` fixture because `v_opportunity_ranking_current` currently contains no PINS row. The refresh bridge does not write ranking tables, so this is recorded as pre-existing ranking/test drift and is not repaired by this PR.

Stored Quality Hardening regression records remain 20/20 PASS.

Do not label these results as GitHub CI; they are live SQL regressions.

## Safety verification

The bridge contains no holdings, transaction, cash, accounting, approval or execution mutation path.

Observed protected-state counts remained:

- `portfolio_transactions`: 58
- `portfolio_source_positions`: 32
- `portfolio_live_holdings_rows_v1`: 15
- `portfolio_accounts`: 3

The existing human approval packet predates this change (2026-09-05).

Policy flags remain:

- `portfolio_mutation=false`
- `approval_mutation=false`
- `execution_mutation=false`
- `auto_trade=false`
- `human_execution_only=true`

## Security follow-up outside this PR

Post-DDL Supabase advisors still report pre-existing database security/performance findings. In particular, RLS is disabled on:

- `fwios.portfolio_live_holdings_batches_v1`
- `fwios.portfolio_live_holdings_rows_v1`
- `fwios.system_state_legacy_archive_v1`

This PR intentionally does not enable RLS because changing those access semantics is a separate security migration that requires consumer/access review.

## Next engineering action

Do not redesign valuation promotion or retune Quality Hardening.

Next MVP-1 work should close the missing canonical hardening evidence path—especially NFLX and EOG Owner Earnings / durability evidence—through the controlled Evidence → Metrics pipeline, then rerun this bridge. Separately repair the stale PINS ranking regression fixture/current ranking drift.
