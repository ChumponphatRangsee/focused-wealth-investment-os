# Phase-1 Portfolio Sheet cleanup — 2026-10-19

## Goal
Reduce `Investment Portfolio Tracker - Chumponphat` to accounting + portfolio display responsibilities while keeping FWIOS/Supabase as the system logic and pricing backend.

## Resulting Sheet structure
Visible:
- Dashboard
- Transactions
- Price Data
- Holdings
- Performance

Hidden helpers:
- Checks
- Lists
- _Market_Data
- FWIOS Live Valuation

Removed:
- Portfolio Guardrails
- Risk Dashboard
- Thesis Tracker
- Thesis History
- Thesis Evidence
- AI Integration Config

## Pricing cleanup
- Supabase `fwios.system_state.architecture_consolidation_v1` now owns `portfolio_price_read_mode=FWIOS_NATIVE`.
- `Price Data` no longer reads a Google Sheet config switch.
- Price formulas read only valuation-eligible native values from `_Market_Data` and fail closed when eligibility is false.
- Manual override column J remains highest priority.
- Legacy fallback/live columns K/L are retained temporarily as rollback reference only; they do not drive the native path.
- `portfolio-sheet-shadow-sync-v1` v6 reads `fwios.v_portfolio_live_positions_current_v1` and publishes market rows for OPEN holdings only.
- `_Market_Data` now contains exactly the 10 distinct open-held assets plus USDTHB FX instead of the prior ~70 active-instrument universe.

## Lists cleanup
Retained only dropdown sources that are still referenced:
- Action
- Asset Class
- Account
- Currency
- Fee Unit
- Dashboard/Performance Account View

Legacy Review Status and Price Source list values were cleared.

## Guardrails and verification
- Transactions and Holdings were byte-for-byte equivalent at the values/formula level to the pre-slim backup immediately after cleanup.
- 15 open account-position rows / 10 distinct open assets remain.
- `FWIOS Live Valuation`: ALL/Best/Loan Money/Mom = PASS, zero unpriced positions, reconciliation delta 0.00.
- Dashboard remains `FWIOS SNAPSHOT`.
- Operational Checks all OK.
- No `#REF!`, `#VALUE!`, `#N/A`, `#ERROR!`, or `#NAME?` were found in the verified operational ranges.
- `auto_trade=false` and `portfolio_mutation=false` remain unchanged.

## Backups
Two Google Sheet backups exist from before destructive cleanup phases:
1. Pre-cleanup Backup 2026-10-19.
2. Pre-slim Backend Cleanup 2026-10-19.

## Deferred
- Live-backend-vs-last-written-Sheet status UX.
- Removal of legacy Price Data K/L after autonomous US-close E2E confidence is established.
- Any stock exact-US-session freshness policy remains explicitly deferred.
