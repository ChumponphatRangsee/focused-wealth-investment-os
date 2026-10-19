# FWIOS Phase-1 — Daily Performance Backend v1 Handover (2026-10-19)

## Purpose

This document hands off the next approved Phase-1 feature:

**Daily Performance Backend v1 + Historical Backfill**

The goal is to make Supabase the durable performance-history backend while keeping Google Sheet as the accounting/source-of-truth surface for transactions and a lightweight performance view.

Repository: `ChumponphatRangsee/focused-wealth-investment-os`  
Canonical branch: `main`  
Supabase project: `ysjbmeukwbfnxnwqchuq`  
Google Sheet: `Investment Portfolio Tracker - Chumponphat`  
Spreadsheet ID: `1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw`

Read first:
1. `docs/implementation/FWIOS_PHASE1_HANDOVER_20261019.md`
2. `docs/implementation/PHASE1_PERFORMANCE_SNAPSHOT_FIX_20261019.md`
3. `AGENTS.md`
4. `contracts/system-contract.yaml`
5. Verify live Supabase + Google Sheet state before changing anything.

---

## Current production state relevant to this feature

### Google Sheet Performance is already repaired

PR #57 is merged to `main`:
`40e569dc39fdb01d75a64df9629e316d5275b4d5`

`portfolio-sheet-shadow-sync-v1` ACTIVE v7 currently writes one frozen Performance snapshot per day for:
- ALL
- Best
- Loan Money
- Mom

The latest verified Performance snapshot on 2026-10-19 was:
- ALL: THB 330,359.61
- Best: THB 224,473.45
- Loan Money: THB 46,094.33
- Mom: THB 59,791.82

Contribution semantics are explicit-only. Never infer deposit/withdrawal from BUY/SELL.

### Backend does NOT yet have canonical daily performance history

Existing tables provide building blocks but are not the target history model:
- `fwios.portfolio_market_quote_snapshots`: ~14,952 rows
- `fwios.portfolio_mtm_runs`: ~2,230 rows
- `fwios.market_observations`: ~19,578 rows
- live holdings/account valuation views are available

`portfolio_mtm_runs` is operational MTM history, not canonical daily account-level NAV/performance history. Historically it ran many times per day.

### The old 15-minute Portfolio/MTM scheduler is gone

Do not recreate it.

Current active Portfolio-related schedules are US-close oriented:
- crypto daily snapshot: 17:10 ET
- stock post-close sync: 17:10 ET Mon-Fri
- native Sheet sync: 17:20 ET

The MTM function remains because the daily US-close flow still uses it.

Historical high-frequency records remain in the database for now. No cleanup is required for this feature.

### Database capacity

Production DB size checked on 2026-10-19: about **83 MB**.

Daily performance volume is tiny:
- 4 account rows/day
- ~1,460 rows/year
- ~14,600 rows/10 years

Do not downgrade to weekly backend storage to save space. Daily backend history is appropriate. Weekly should only be a Sheet/display concern.

---

## Agreed architecture

```
Google Sheet Transactions (accounting source of truth)
            |
            | historical reconstruction / explicit flows only
            v
Historical prices + FX
            |
            v
Daily account valuation
            |
            v
fwios.portfolio_performance_daily_snapshots_v1
            |
            +--> permanent daily backend history
            |
            +--> Google Sheet Performance
                 weekly history + latest view (after backend is proven)
```

Normal daily operation must reuse the existing pricing/valuation path and must **not add market-data API calls solely for Performance**.

Expected normal cadence:

```
US close / market daily close
        |
17:10 ET stock + crypto portfolio valuation
        |
Daily Performance snapshot/upsert
        |
17:20 ET Google Sheet sync
```

Exact integration point may be implemented in the existing sync flow or a small dedicated writer, but avoid creating another pricing pipeline.

---

## Proposed backend table

Recommended table:

`fwios.portfolio_performance_daily_snapshots_v1`

Minimum useful fields:

- `snapshot_date date not null`
- `account_key text not null`
- `holdings_value_thb numeric not null`
- `cash_value_thb numeric null`
- `nav_thb numeric null`
- `net_external_flow_thb numeric not null default 0`
- `cumulative_external_flow_thb numeric null`
- `realized_pnl_thb numeric null`
- `unrealized_pnl_thb numeric null`
- `total_pnl_thb numeric null`
- `daily_return numeric null`
- `cumulative_return numeric null`
- `peak_value_thb numeric null`
- `drawdown_pct numeric null`
- `valuation_basis text not null`
- `data_quality_status text not null`
- `source_batch_id uuid/text nullable as appropriate to current lineage contract`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Unique key:
`(snapshot_date, account_key)`

Reruns must UPSERT the same account/day row, never create duplicates.

Expected account keys:
- ALL
- best
- loan_money
- mom

Follow existing repository naming conventions if canonical account keys differ in current contracts.

Enable RLS/policies correctly at creation. Do not copy the unrelated current RLS gaps into the new table.

---

## External cash-flow rule — critical

Do not infer cash contribution from BUY/SELL.

Examples:

```
SELL NVDA -> BUY TTWO
external flow = 0
```

Only explicit deposit/withdrawal should change external flow.

The current transaction history is sufficient to reconstruct positions and realized trades, but it does not automatically prove complete historical deposits/withdrawals.

Therefore historical snapshots must support honest quality states, e.g.:
- `valuation_basis=HOLDINGS_ONLY`
- `data_quality_status=PARTIAL`

until explicit cash-flow history is available.

Do not manufacture TWR/XIRR from incomplete cash-flow information.

---

## Historical backfill scope

Earliest known transaction in the Sheet:
- Mom: 2024-06-03
- Best: 2024-09-10
- Loan Money: 2025-09-25
- ALL: begins 2024-06-03

Target backfill window:
**2024-06-03 through the day before canonical automatic daily backend snapshots begin.**

Backfill flow:

```
Transactions
  -> reconstruct end-of-day quantity by account/asset
  -> historical daily close price
  -> historical USD/THB where required
  -> account holdings valuation
  -> daily performance snapshot
```

Historical prices should be fetched/cache-efficiently by time series, not one API call per asset/day.

Backfill is a one-time exception where historical market-data API use may be required. Respect provider quota and cache all acquired history.

Do not overwrite live accounting or source transactions during backfill.

---

## Performance metrics — Phase 1 scope

Implement first:
- holdings value
- total portfolio/account value where cash is reliably known
- realized P&L where reconstructable
- unrealized P&L where reconstructable
- total P&L
- daily return when mathematically valid
- since-inception return when mathematically valid
- peak value
- drawdown

TWR:
- calculate only where external-flow history is explicit/reliable
- otherwise leave null / mark partial rather than inventing flows

Defer:
- XIRR / money-weighted return
- S&P 500 benchmark
- Sharpe / Sortino
- more advanced analytics

Keep Phase 1 usable and simple.

---

## Google Sheet transition plan

Do NOT immediately remove the existing daily Performance writer.

Safe transition:
1. Build backend table.
2. Write/verify daily backend snapshots.
3. Reconcile backend values against Sheet Performance for several runs.
4. Backfill history.
5. Only after validation, change Google Sheet Performance history to **weekly + latest** if still desired.
6. Keep live summary values on the Sheet.

Supabase = durable daily history.  
Google Sheet = accounting/reconciliation/user-facing summary.

---

## Implementation task checklist

### Task 1 — schema
- create migration for `portfolio_performance_daily_snapshots_v1`
- unique account/date key
- indexes needed for account/date reads
- RLS/policies
- no public write path unless explicitly required

### Task 2 — daily writer
- source current account valuation from the existing live valuation path
- write exactly four account/day rows
- idempotent upsert
- preserve explicit external-flow input
- record source lineage/batch
- no extra market API request
- `auto_trade=false`, no portfolio mutation

### Task 3 — reconciliation
Verify:
`ALL = Best + Loan Money + Mom`
within a small numeric tolerance.

For the 2026-10-19 known reference:
- ALL ~330,359.61 THB
- Best ~224,473.45 THB
- Loan Money ~46,094.33 THB
- Mom ~59,791.82 THB

Do not hardcode these values; use only as reconciliation evidence.

### Task 4 — historical reconstruction/backfill
- read transactions from authoritative Sheet/source contract
- reconstruct EOD positions
- acquire/cache historical price + FX series
- create daily rows from 2024-06-03
- mark incomplete-flow periods honestly
- make backfill resumable/idempotent

### Task 5 — Performance calculations
- daily return
- cumulative/since-inception return where valid
- peak NAV/value
- drawdown
- clear null/partial semantics

### Task 6 — Sheet cutover after backend validation
- backend remains daily
- Sheet history becomes weekly + latest if desired
- keep summary/live account view
- no accounting formula mutation

### Task 7 — monitoring
Add minimal state/receipt such as:
- last successful performance snapshot date
- row count/accounts written
- reconciliation status
- source batch
- PASS/STALE/ERROR

Reuse existing system-state/receipt patterns. Do not create a large monitoring subsystem.

---

## Guardrails

Hard requirements:
- Google Sheet Transactions remains transaction/accounting source of truth
- do not create a second transaction ledger
- do not infer external contributions from BUY/SELL
- do not mutate Holdings quantities/cost basis/source formulas
- do not increase market API usage in normal daily operation
- do not restore 15-minute Portfolio/MTM polling
- idempotent reruns
- `auto_trade=false`
- human execution only
- keep implementation Phase-1 sized

---

## Known unrelated security item

During inspection, Supabase reported RLS disabled on:
- `fwios.portfolio_live_holdings_batches_v1`
- `fwios.portfolio_live_holdings_rows_v1`
- `fwios.system_state_legacy_archive_v1`

This is a separate security-hardening task.

Do **not** blindly enable RLS as part of Daily Performance work because existing workers may depend on current access semantics. Review policies/access paths separately.

The new Performance table itself should be created securely from day one.

---

## Definition of Done

The feature is accepted when:

1. Supabase contains one canonical daily row per account/day.
2. A rerun on the same date does not duplicate rows.
3. Daily write uses existing valuation results with no Performance-specific market quote calls.
4. ALL reconciles to child accounts.
5. Historical daily valuation exists from the earliest reconstructable date.
6. Incomplete external cash-flow periods are explicitly marked partial; no invented TWR.
7. Google Sheet and backend reconcile for overlapping snapshots.
8. No Transactions/Holdings accounting mutation occurs.
9. `auto_trade=false`.
10. Documentation/runbook is updated.

---

## Next-chat kickoff prompt

```
Continue FWIOS Phase-1 Daily Performance Backend v1 from:

docs/implementation/PHASE1_DAILY_PERFORMANCE_BACKEND_HANDOVER_20261019.md

Repository:
ChumponphatRangsee/focused-wealth-investment-os

Also read:
- docs/implementation/FWIOS_PHASE1_HANDOVER_20261019.md
- docs/implementation/PHASE1_PERFORMANCE_SNAPSHOT_FIX_20261019.md
- AGENTS.md
- contracts/system-contract.yaml

Before changing anything, verify CURRENT live Supabase and Google Sheet state.

Goal:
Implement Daily Performance Backend v1 and then historical backfill.

Key constraints:
- Supabase stores permanent DAILY performance history.
- Google Sheet remains transaction/accounting source of truth.
- Do not create another transaction ledger.
- Do not infer deposits/withdrawals from BUY/SELL.
- Normal daily Performance must add zero market-data API calls; reuse existing US-close valuation.
- Do not restore 15-minute MTM polling.
- Use idempotent upsert keyed by snapshot_date + account.
- Accounts: ALL / Best / Loan Money / Mom.
- Historical reconstruction starts from 2024-06-03 where data permits.
- Mark incomplete historical cash-flow periods PARTIAL/HOLDINGS_ONLY rather than inventing TWR.
- auto_trade=false and no accounting mutation.

Start with schema + daily writer + reconciliation. Verify production behavior before starting historical backfill.
```
