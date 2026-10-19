# Focused Wealth Dashboard PR-B — Cleanup & Contract Alignment Handover (2026-10-19)

## Scope

PR-B follows PR-A scanner separation and finishes the non-destructive cleanup boundary:

1. verify PR-A and current live Sheet/Supabase state;
2. remove the scanner Sheet dependency on legacy `_Data!V1`;
3. validate Scanner + Valuation Map against Supabase;
4. audit legacy consumers before retirement;
5. align repository source, agent rules, and system contract.

No portfolio accounting or execution path is modified.

## Live State Verified Before Writes

- PR #59 open, mergeable, base `main`;
- Supabase project `focused-wealth-investment-os` ACTIVE_HEALTHY;
- `fwios.v_scanner_current_v1` live;
- `scanner-refresh-csv-v1` was ACTIVE v2 at entry;
- visible Sheet tabs: `S&P500 Scanner`, `Valuation Map`;
- hidden legacy tabs: `Dashboard`, `Thesis Tracker`, `Opportunity Quality`, `_Data`;
- hidden scanner helper: `_Scanner_Data`;
- live universe: 64 ACTIVE Stock + 6 ACTIVE Crypto instruments;
- scanner: 64 rows, 27 scored, 7 undervalued/strong-undervalued;
- price sessions: 2026-10-15 through 2026-10-16;
- invalid scanner ranks: 0;
- `auto_trade=false`, `human_execution_only=true`.

## Credential / Configuration Decoupling

The scanner now has a scanner-specific import credential.

Security rules:
- raw credential is not stored in GitHub, docs, PR text, or contract files;
- Supabase stores only the SHA-256 credential hash;
- the raw import URL exists only in hidden Google Sheet configuration required by `IMPORTDATA`;
- scanner access is read-only to the scanner CSV endpoint.

Sheet path:

`_Scanner_Config!A1 -> _Scanner_Data!A1 IMPORTDATA -> S&P500 Scanner / Valuation Map`

There is no `_Data` dependency in this path.

Live function:
- `scanner-refresh-csv-v1` ACTIVE v4;
- v4 accepts only the scanner-specific access key.

## Post-Cutover Validation

After the final v4 refresh:
- 64 scanner rows;
- 27 scored;
- 7 undervalued/strong-undervalued;
- top ranks remained ADBE, PINS, QCOM, NFLX, EOG at verification time;
- current Scanner prices/fair values matched `fwios.v_scanner_current_v1`;
- Valuation Map remained sourced from `_Scanner_Data`;
- no `#REF!`, `#N/A`, or `#VALUE!` in `S&P500 Scanner`, `Valuation Map`, or `_Scanner_Data`;
- `auto_trade=false`, human execution only.

Rankings are time-sensitive and must always be re-read from live state.

## Consumer / Dependency Audit

### Safe to classify as legacy UI/feed chain

- hidden `Dashboard`;
- hidden `Thesis Tracker`;
- hidden `Opportunity Quality`;
- hidden `_Data`;
- `dashboard-refresh-csv-v1`;
- `fwios.dashboard_refresh_payload_v1()`.

Findings:
- no pg_cron jobs reference dashboard/scanner refresh endpoints;
- no other FWIOS Postgres function calls `dashboard_refresh_payload_v1()`;
- among deployed dashboard-refresh Edge Functions, only `dashboard-refresh-csv-v1` calls that payload.

### Must remain

The scanner still depends on active research/valuation infrastructure. In particular, PR-A currently reads valuation/thesis information through existing backend views. Do not remove:
- canonical identity / market-price infrastructure;
- research candidates;
- thesis registry/tracking services;
- valuation models/runs/scenarios;
- `v_dashboard_valuation_map` while `v_scanner_current_v1` still consumes it;
- `v_thesis_tracking_current`;
- opportunity scoring function;
- cache/quota/scheduler infrastructure.

## Retirement Decision

PR-B intentionally does **not** delete legacy Sheet tabs, `dashboard-refresh-csv-v1`, or `dashboard_refresh_payload_v1()` yet.

Reason:
- the active scanner is now fully decoupled, so legacy components are no longer required for the new surface;
- keeping them hidden/live for the stacked PR merge window preserves cheap rollback;
- deleting them now produces little user benefit because the tabs are already hidden.

Contract status is therefore `DEPRECATED_ROLLBACK_ONLY`.

After PR-A + PR-B land and the rollback window is intentionally closed, a small follow-up may:
1. delete legacy hidden Sheet tabs;
2. disable/remove the legacy dashboard feed credential;
3. remove the legacy Edge Function if tooling permits;
4. drop `dashboard_refresh_payload_v1()` only after one final consumer check;
5. keep any shared backend views that still have scanner/portfolio consumers.

## Active User-Facing Contract

Visible:
- `S&P500 Scanner`
- `Valuation Map`

Hidden/backend:
- `_Scanner_Data`
- `_Scanner_Config`
- canonical identity / market data
- research / thesis engines
- valuation engines
- cache / quota
- scheduler

Portfolio accounting authority:
- `Investment Portfolio Tracker - Chumponphat`

Focused Wealth Dashboard is research/scanner presentation only and must not become a second accounting system.

## Next Separate Task — Full S&P 500 Universe

Current 64-stock coverage must not be described as full S&P 500 coverage.

The next implementation should add:
- authoritative constituent source and membership lifecycle;
- canonical ticker/company/sector identity;
- additions/removals handling;
- quota-aware EOD pricing, cache-first ingestion and batching;
- scanner eligibility and coverage state;
- graceful `PRICE_ONLY` / `NO VALUATION` states;
- shallow cheap coverage for ~500 symbols;
- selective deep valuation/research only for candidates.

Do not run expensive AI/research over all ~500 names every day.

## Safety Invariants

- no transaction mutation;
- no cost-basis mutation;
- no realized P&L mutation;
- no cash mutation;
- no holding-quantity mutation;
- no accounting formula mutation in Investment Portfolio Tracker;
- no execution-path mutation;
- `auto_trade=false`;
- `human_execution_only=true`.
