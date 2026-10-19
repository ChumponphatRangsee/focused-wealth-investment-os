# FWIOS Phase-1 — Handover to next chat (2026-10-19, Asia/Bangkok)

## Current production state — authoritative as of 2026-10-19 ~10:03 Bangkok

Repository: `ChumponphatRangsee/focused-wealth-investment-os`  
Canonical branch: `main`  
Current main SHA before this handover update: `40e569dc39fdb01d75a64df9629e316d5275b4d5`  
Supabase project: `ysjbmeukwbfnxnwqchuq`  
Google Sheet: `Investment Portfolio Tracker - Chumponphat`  
Spreadsheet ID: `1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw`

Hard guardrails remain:
- `auto_trade=false`
- `portfolio_mutation=false`
- human execution only
- never rewrite Transactions, cost basis, realized P&L, cash, accounting quantities, or source Holdings formulas

## What was completed in this chat

### 1. Crypto UTC rollover bug — fixed
PR #55 merged: `f6b63bd4186a2d676f7b5412f03d633e421d5778`

The crypto native-price freshness rule no longer requires `session_date = current UTC date`. Crypto remains valid only when provenance/price/future guards pass and quote age is <= 30 hours.

Current result:
- BTC / DOGE / ETH / HBAR / SOL / XRP = `FRESH`, valuation eligible
- MSFT / NVDA / TLN / TTWO = `LAST_CLOSE`, valuation eligible
- live valuation = PASS
- 0 unpriced positions

Do not reintroduce the old UTC-date equality.

### 2. Portfolio Tracker cleanup — complete
PR #56 merged: `1243270d69a4e8e03ac5a93a09ba30b6ac97a5aa`

Removed obsolete Sheet tabs:
- Portfolio Guardrails
- Risk Dashboard
- Thesis Tracker
- Thesis History
- Thesis Evidence
- AI Integration Config

Retained user-facing accounting/display tabs:
- Dashboard
- Transactions
- Price Data
- Holdings
- Performance

System/helper tabs:
- Checks
- Lists
- _Market_Data
- FWIOS Live Valuation

At the latest inspection, `_Market_Data` is intentionally unhidden because the user was reviewing its fields. Checks, Lists and FWIOS Live Valuation remain hidden. It can be re-hidden later without changing logic.

`Lists` was reduced to values still used by dropdowns:
- Action
- Asset Class
- Account
- Currency
- Fee Unit
- Dashboard/Performance Account View

Legacy Review Status and Price Source values were removed.

### 3. Price mode ownership moved out of Google Sheet
The former `AI Integration Config!B21=FWIOS_NATIVE` dependency is gone.

Current system config:
`fwios.system_state -> architecture_consolidation_v1.state_value.portfolio_price_read_mode = FWIOS_NATIVE`

Also:
`portfolio_sheet_shadow_scope = OPEN_HOLDINGS_ONLY`

`Price Data` now reads native eligible values directly from `_Market_Data`; manual override column J remains highest priority. Legacy K/L fallback/live columns are kept only as rollback references for now.

### 4. _Market_Data slimmed to open holdings only
The previous worker wrote ~70 active instruments. That was removed.

Current path:
`fwios.v_portfolio_live_positions_current_v1`
→ distinct OPEN held assets
→ `fwios.pr7_native_usd_price_read_v1`
→ `_Market_Data`
→ `Price Data`
→ `Holdings`

Current `_Market_Data` contains exactly these 10 assets:
`BTC, DOGE, ETH, HBAR, MSFT, NVDA, SOL, TLN, TTWO, XRP`

No non-held active-universe rows should return on the next sync.

### 5. Shared USD/THB FX layout clarified
Columns R:X in `_Market_Data` are a single shared FX block, not BTC-specific data.

Current labels:
- FX Pair
- THB per USD
- FX Provider
- Observation ID
- Observed At
- Session Date
- Provenance

Current FX example:
- pair: `USDTHB`
- rate: `33.45758`
- provider: `TWELVE_DATA_FX`
- provenance: `PASS`

The values live in row 2 because formulas use `$S$2`; every open-held USD/USDT asset uses the same rate. A note was added below the block stating that it is shared across all open-held assets and is not BTC-specific.

Do not duplicate the FX metadata on every asset row unless the architecture is intentionally changed.

### 6. Performance daily snapshots restored
PR #57 merged: `40e569dc39fdb01d75a64df9629e316d5275b4d5`

Root cause: the Sheet sync worker updated market data and valuation but did not append current daily Performance snapshots.

`portfolio-sheet-shadow-sync-v1` is now ACTIVE v7 and writes verified daily frozen snapshots for:
- ALL
- Best
- Loan Money
- Mom

Latest Sheet Performance rows include 2026-10-19 for all four account views.

Contribution semantics are explicit-only; BUY/SELL must never be inferred as deposit/withdrawal.

## Latest verified live production state

Supabase current:
- `fwios.v_portfolio_market_price_health`: 10 open assets / 10 fresh / `pricing_gate=PASS`
- `fwios.v_portfolio_live_account_valuation_v1`:
  - ALL: THB 330,359.61 | 15 rows | 10 assets | 0 unpriced | PASS
  - Best: THB 224,473.45 | 7 rows | 7 assets | 0 unpriced | PASS
  - Loan Money: THB 46,094.33 | 6 rows | 6 assets | 0 unpriced | PASS
  - Mom: THB 59,791.82 | 2 rows | 2 assets | 0 unpriced | PASS
- `portfolio_tracker_shadow_sync_status=PASS`
- latest shadow attempt: `2026-10-19T03:03:40.496Z`
- `auto_trade=false`
- `portfolio_mutation=false`

Google Sheet latest:
- `FWIOS Live Valuation` synchronized around `2026-10-19T03:03:39Z`
- all four account gates = PASS
- all reconciliation deltas = 0.00
- Dashboard Account View = ALL
- Dashboard Value Source = `FWIOS SNAPSHOT`
- Dashboard Portfolio Value ~ THB 330,360
- Checks = all OK
- no formula errors observed in the verified operational ranges

Transactions and Holdings were compared against the pre-slim backup after cleanup and remained unchanged.

## Current deployed functions relevant to Phase 1

- `market-daily-close-worker-v1` ACTIVE v3
- `portfolio-mtm-refresh-v1` ACTIVE v7
- `portfolio-sheet-shadow-sync-v1` ACTIVE v7

The Sheet sync worker now:
1. requires Supabase `portfolio_price_read_mode=FWIOS_NATIVE`
2. publishes only open-held assets
3. writes shared FX
4. reads Holdings without mutating accounting
5. refreshes live position projection
6. publishes live account valuation
7. publishes daily Performance snapshots
8. records verified state receipts

## Completed PRs in the current Phase-1 stack

- #49 Provider Quota → `549faaba65174d86569dc35ce6164b185f78c29e`
- #50 Atomic Quota → `26be8ed411464a220f12965046ab98aad17a6934`
- #51 Cache / Single-flight / Priority → `738053102456fe47c633a015def02ac60abc107a`
- #52 Native USD shadow → `ea5c99414cf430f7613279b42bbc046b8e659800`
- #53 Live Holdings projection / system state / verified Sheet sync → `cf24cff4b8af070ef6a9879158df573240cadae5`
- #54 Live valuation Sheet cutover → `ad9989b4cec0ebadbbe644e3d57f010b45bb8da0`
- #55 Crypto UTC rollover fix → `f6b63bd4186a2d676f7b5412f03d633e421d5778`
- #56 Portfolio Tracker cleanup / open-holdings-only shadow → `1243270d69a4e8e03ac5a93a09ba30b6ac97a5aa`
- #57 Performance daily snapshot fix → `40e569dc39fdb01d75a64df9629e316d5275b4d5`

Relevant docs:
- `docs/implementation/PHASE1_P3_P4_P5_ACCEPTANCE_20261017.md`
- `docs/implementation/PHASE1_SHEET_LIVE_VALUATION_CUTOVER_20261017.md`
- `docs/implementation/PHASE1_CRYPTO_UTC_ROLLOVER_FIX_20261019.md`
- `docs/implementation/PHASE1_PORTFOLIO_SHEET_CLEANUP_20261019.md`
- `docs/implementation/PHASE1_PERFORMANCE_SNAPSHOT_FIX_20261019.md`

## Autonomous schedule / E2E verification

FWIOS production itself runs via Supabase/pg_cron. ChatGPT automations are external verification only and are not required to operate FWIOS.

Expected production cadence is DST-guarded in America/New_York:
- EOD enqueue 16:05 ET
- EOD worker 16:05–17:05 ET
- stock + crypto refresh 17:10 ET
- native Sheet / valuation / performance sync 17:20 ET

The full autonomous U.S.-equity-close E2E is still awaiting the next real U.S. sessions.

Acceptance requires:
- actual US close ingest
- held stock close observations eligible
- crypto snapshot fresh under 30h rule
- valid USDTHB
- Holdings projection refreshed
- live valuation PASS / zero unpriced
- Sheet valuation reconciliation zero
- Performance snapshot written
- autonomous cron/worker evidence
- no accounting mutation / `auto_trade=false`

Important: do not manually trigger workers to make a failed autonomous session pass.

### ChatGPT verification automations
Two enabled E2E verifier automations currently exist:
- 2026-10-20 and 2026-10-21 at **04:35 Bangkok**
- 2026-10-20 and 2026-10-21 at **04:40 Bangkok**

They are redundant external verifiers. They do not affect FWIOS production. The newer 04:40 task has the more complete acceptance checklist. New chat may disable the older 04:35 duplicate if desired.

## Explicitly deferred / do not reopen automatically

1. **System Status / stale monitor tab** — user decided to postpone this feature.
2. **Exact-US-stock-session freshness gate** — explicitly deferred by the user. Do not implement without a new request.
3. **Price Data K/L removal** — keep as rollback reference until autonomous US-close E2E confidence is established.
4. **Focused Dashboard MVP** — start only after pricing path is considered stable.
5. Benchmark expansion for Performance — deferred in Phase 1.
6. Do not reintroduce old thesis/risk/AI config tabs into the accounting tracker.

## Next task in the new chat

### Priority 1 — Observe autonomous US-close E2E
Do not make another architecture change first.

For the next eligible U.S. session, verify:
- market close cron/worker receipts
- 4 held stock prices/session dates
- 6 crypto snapshots and 30h freshness
- USDTHB provenance
- 10/10 market-price health
- 15 live account-position rows / 10 assets
- four account valuation gates PASS and zero unpriced
- Google Sheet valuation readback/delta
- Performance daily snapshot
- no source accounting changes

Count only a genuine autonomous U.S. equity-close session. A DST guard-suppressed run or manual invocation does not count.

Goal: obtain 1–2 consecutive accepted sessions, then declare:
`Pricing Path Stable ✅`

### Priority 2 — Regression checks
After a real scheduled cycle:
- confirm legacy CoinGecko Apps Script remains absent and does not overwrite crypto Price Data G/H/M
- confirm `_Market_Data` remains exactly open holdings only
- confirm FX block remains shared and valid
- confirm Performance writes one correct daily snapshot per account/day

### Priority 3 — then simplify further
After stable E2E:
- consider removing legacy Price Data K/L rollback columns
- optionally re-hide `_Market_Data` after user inspection
- proceed to Focused Dashboard MVP

## Read-first instructions for the next chat

1. Read this handover completely.
2. Read `AGENTS.md` and `contracts/system-contract.yaml`.
3. Read the five implementation docs listed above.
4. Inspect live Supabase state before changing anything:
   - `fwios.v_portfolio_market_price_health`
   - `fwios.v_portfolio_live_account_valuation_v1`
   - `fwios.system_state`
   - relevant cron/job receipts
5. Inspect the live Google Sheet:
   - Dashboard
   - Price Data
   - Holdings
   - Performance
   - _Market_Data
   - FWIOS Live Valuation
   - Checks
6. Never use old handover snapshot text in preference to live production state.

## Suggested kickoff prompt for the new chat

```
Continue FWIOS Phase-1 from:
docs/implementation/FWIOS_PHASE1_HANDOVER_20261019.md

Repository:
ChumponphatRangsee/focused-wealth-investment-os

First read the handover, AGENTS.md, contracts/system-contract.yaml, and the referenced Phase-1 implementation docs. Then verify the CURRENT live Supabase + Google Sheet state before making any changes.

Current expected state:
- PRs #49–#57 merged to main.
- crypto UTC rollover bug fixed.
- portfolio-sheet-shadow-sync-v1 ACTIVE v7.
- pricing mode owned by Supabase: FWIOS_NATIVE.
- _Market_Data scope is OPEN_HOLDINGS_ONLY and should contain exactly 10 held assets + one shared USDTHB FX block.
- AI Integration Config and old thesis/risk tabs are removed.
- live valuation should be PASS / 0 unpriced for ALL, Best, Loan Money, Mom.
- Performance daily snapshots are restored.
- auto_trade=false and portfolio_mutation=false.
- System Status/stale-monitor feature is deferred.
- exact-US-stock-session freshness gate is explicitly deferred.

FIRST PRIORITY:
Observe and verify the next genuine autonomous U.S.-close E2E session. Do not manually trigger workers to manufacture a pass. Check cron/worker evidence, 4 held stocks, 6 crypto assets, USDTHB, live Holdings projection, valuation, Google Sheet reconciliation, Performance snapshot, and confirm accounting data did not mutate.

After 1–2 consecutive autonomous sessions pass, declare Pricing Path Stable and then discuss the Focused Dashboard MVP / final legacy K-L cleanup.
```


---

## Latest approved task after this handover was written

The user has now approved planning/implementation of a new feature:

**Daily Performance Backend v1 + Historical Backfill**

Canonical feature handover:
`docs/implementation/PHASE1_DAILY_PERFORMANCE_BACKEND_HANDOVER_20261019.md`

This is the latest task directive for the next chat.

Important clarification:
- the old 15-minute Portfolio/MTM scheduler has already been removed and must not be restored
- current Portfolio MTM is US-close oriented
- Supabase should keep canonical DAILY performance history
- normal Daily Performance must reuse current valuation and add no market-data API calls
- Google Sheet Transactions remains the accounting source of truth
- contributions must not be inferred from BUY/SELL
- historical backfill begins from 2024-06-03 where reconstructable
- incomplete historical cash-flow periods must be marked PARTIAL/HOLDINGS_ONLY rather than inventing TWR
- existing autonomous US-close E2E verification remains a regression guard, but it no longer blocks beginning the approved Daily Performance schema/writer work

Next chat should read the dedicated Daily Performance handover before implementation.


---

## Focused Wealth Dashboard scanner addendum — 2026-10-19

A later Phase-1 task separated the Focused Wealth Dashboard from portfolio accounting.

Current Focused Dashboard state:
- visible tabs: `S&P500 Scanner`, `Valuation Map`;
- active Supabase read model: `fwios.v_scanner_current_v1`;
- active feed: `scanner-refresh-csv-v1` v4;
- hidden helpers: `_Scanner_Data`, `_Scanner_Config`;
- `_Scanner_Data` no longer depends on legacy `_Data`;
- current backend stock universe: 64 ACTIVE stocks, not full S&P 500;
- scanner excludes holdings/account/portfolio-fit/position-sizing/cash/P&L/approval/execution state;
- legacy `Dashboard`, `Thesis Tracker`, `Opportunity Quality`, `_Data`, legacy feed and payload remain rollback-only for now;
- portfolio accounting remains owned by `Investment Portfolio Tracker - Chumponphat`;
- `auto_trade=false`, human execution only.

Canonical cleanup/handover:
`docs/implementation/FOCUSED_DASHBOARD_PR_B_CLEANUP_HANDOVER_20261019.md`
