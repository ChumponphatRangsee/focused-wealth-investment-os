# FWIOS Phase-1 — Post PR #52 Handover to Next Chat

**Date:** 2026-10-17  
**Repository:** `ChumponphatRangsee/focused-wealth-investment-os`  
**Current integration branch:** `feat/pr4-cache-singleflight-priority`  
**Current branch head:** `ea5c99414cf430f7613279b42bbc046b8e659800`

## Current PR stack state

- PR #52 — **MERGED** into PR #51 branch
  - Merge commit: `ea5c99414cf430f7613279b42bbc046b8e659800`
  - PR #52 is closed/merged.
- PR #51 — OPEN / DRAFT / mergeable
  - base: `feat/pr3-atomic-unified-quota`
  - head: `feat/pr4-cache-singleflight-priority`
  - current head already includes PR #52.
- PR #50 — OPEN / DRAFT / mergeable
  - base: `feat/pr2-unified-provider-quota-policy`
  - head: `feat/pr3-atomic-unified-quota`
- PR #49 — OPEN / DRAFT / mergeable
  - base: `main`
  - head: `feat/pr2-unified-provider-quota-policy`

Latest CI on the post-PR52 PR51 head:
- PR4 mock Edge-core E2E — PASS
- PR5 Native USD Adapter (offline) — PASS

**Important:** PR #52 is merged into the stack, but the PR2→PR5 stack is **not yet in `main`**.

## What PR #52 completed

### Native USD market data
- Supabase canonical market-data path now exposes native USD asset prices.
- USDTHB is a separate FX reference.
- Historical THB observations/trades were not relabeled or rewritten.
- Stocks use canonical `REGULAR_CLOSE` and are exposed downstream as `LAST_CLOSE`.
- Crypto uses a daily `CRYPTO_DAILY_SNAPSHOT` / `FRESH` path.
- `auto_trade=false`.

### Portfolio refresh policy
- Removed the former high-frequency portfolio polling behavior.
- Current Phase-1 schedule follows the US market clock using `America/New_York` guards:
  - EOD enqueue: 16:05 ET weekdays.
  - EOD worker window: 16:05–17:05 ET weekdays.
  - Held-stock portfolio sync: 17:10 ET weekdays, only when current-session canonical close coverage is complete.
  - Crypto snapshot: 17:10 ET daily.
  - Native Google Sheet sync: 17:20 ET daily.
- DST is handled by New York local-time guards.
- No intraday held-stock quote polling is active.

### Google Sheet native sync
Google Sheet:
`Investment Portfolio Tracker - Chumponphat`

Spreadsheet ID:
`1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw`

Hidden tab:
`_Market_Data`

Native sync:
- Edge Function: `portfolio-sheet-shadow-sync-v1`
- ACTIVE v2
- Google service-account credential stored in Supabase Vault.
- Native write/read-back passed.
- 70 market-data rows written.
- 10/10 open holdings covered.
- USDTHB provenance PASS.

Temporary ChatGPT `FWIOS Sheet Shadow Sync` automation is disabled.

### Controlled Price Data cutover
Production read path is now:

`Supabase canonical market data → _Market_Data → Price Data → Holdings`

Google Sheet rollback control:
- `AI Integration Config!B21`
- current value: `FWIOS_NATIVE`
- rollback value: `LEGACY`

Behavior:
- Manual Override remains highest priority.
- Current open Stock/Crypto rows read native USD + validated USDTHB from `_Market_Data`.
- Native-scoped failure is fail-closed; do not silently use legacy price.
- Legacy Live Price column remains as rollback-side input.
- CASH remains fixed.
- VOO / non-open unsupported rows remain on legacy behavior for Phase 1.

Backend cutover gate:
- `fwios.pr7_native_usd_price_read_v1(text)`
- migration: `migrations/20261017114500_pr7_native_price_read_cutover_v1.sql`
- current 10/10 open holdings pass native valuation eligibility.
- `trading_eligible=false`.

Post-cutover portfolio value:
- Best ≈ THB 226,107.96
- Loan Money ≈ THB 47,446.25
- Mom ≈ THB 60,270.93
- ALL ≈ THB 333,825.15

This matched the pre-cutover shadow reconciliation.

No rewrite was made to:
- Transactions
- quantities
- Holdings formulas
- Cost Basis
- realized P&L
- cash records
- trade execution

## Remaining tasks

### P0 — integrate the remaining stacked PRs into main
Do **not** assume PR #52 merge means main is updated.

Required stack order:
1. merge PR #51 into PR #50 branch;
2. merge PR #50 into PR #49 branch;
3. merge PR #49 into `main`.

Before each merge:
- re-read the PR state and base/head;
- confirm mergeable;
- confirm CI on the current head;
- use expected head SHA when merging;
- re-read the downstream PR after the merge because its head will move.

Do not force-update refs or squash history unless required by a real conflict.

### P0 — documentation consolidation
Several older documents contain superseded states such as:
- fixed 07:00 / 07:10 Asia/Bangkok schedules;
- `Price Data cutover NOT DONE`;
- PR #52 Draft/Unmerged;
- older shadow-only semantics.

Keep old migration/history evidence, but make current sections explicit and mark older operational states as **superseded** to avoid contradictory handovers.

Priority docs:
- `docs/implementation/PR7_HANDOVER_TO_NEXT_CHAT_20261017.md`
- `docs/implementation/PR7_NATIVE_SHEET_SHADOW_SYNC_RUNBOOK_20261017.md`
- `docs/implementation/PHASE1_MVP_FIRST_ROADMAP_20261016.md`
- architecture/runbook references that still describe the fixed Bangkok cadence.

### P0/P1 — identify and retire the legacy direct-CoinGecko Sheet writer
During Price Data cutover, a legacy process briefly rewrote crypto audit/status / legacy Live Price cells.

Known facts:
- It did not change the native Resolved Price valuation path after repair.
- Subsequent read-back remained `FWIOS_NATIVE / FRESH`.
- It was not caused by an active ChatGPT portfolio automation.
- It was not found in the current Supabase portfolio/sheet Cron jobs.
- Legacy Live Price column should remain available for rollback, but the old process should not overwrite authoritative native audit/status fields.

Next action:
1. identify the trigger/source;
2. confirm exactly which cells/ranges it writes;
3. disable it or restrict it to rollback-only legacy inputs;
4. verify one full cycle that native audit/status remains untouched.

Do not delete rollback data until the source is identified and a rollback test has passed.

### P1 — verify autonomous scheduled E2E for 1–2 US sessions
Observe normal scheduled execution with no manual trigger:

`16:05 ET EOD ingest → 17:10 ET portfolio refresh → 17:20 ET _Market_Data sync → Price Data → Holdings`

Validate:
- MSFT/NVDA/TLN/TTWO use the newest completed regular session.
- same-session held-stock gate behaves fail-closed.
- all 6 crypto holdings receive the daily snapshot.
- USDTHB provenance is PASS.
- 10/10 open holdings remain valuation eligible.
- Holdings total remains internally consistent.
- `auto_trade=false`.

Do not add a high-frequency retry loop unless an actual missed-session problem occurs.

### P1 — holiday / early-close efficiency
Current holiday behavior is safe but not optimal:
- full US holiday can enqueue work, then fail closed because no exact session exists.
- early-close days are processed later at the normal 16:05 ET cadence rather than immediately after the early close.

This is quota/latency cleanup, not a valuation-correctness blocker.

Potential future improvement:
- exchange-calendar aware full-holiday skip;
- optional early-close-aware scheduling.

Keep this lightweight for Phase 1.

### P1 — retire obsolete shadow/canary/probe components
After the stack is safely in main and scheduled E2E is stable:
- inspect callers for `market-price-usd-shadow-v1`;
- inspect old canary/probe Edge Functions;
- inspect old shadow-only migrations/runbooks;
- deactivate components with no active caller.

Do not bulk-delete diagnostics. Verify callers first and keep anything still useful for rollback/support.

### P2 — Supabase hygiene
Supabase advisor still reports older schema debt including RLS-without-policy and index recommendations.

These warnings were not introduced by the Price Data cutover and should not block Phase-1 usability.

Handle separately as technical-debt/security-hardening work after the user-facing workflow is stable.

## Phase-1 architecture rules to preserve

- Google Sheet remains transaction/accounting source-of-truth.
- Supabase is canonical market-data/state infrastructure.
- Do not create a second transaction ledger in Supabase for this workflow.
- Native USD is the canonical asset-price unit.
- USDTHB remains separate FX.
- Never call `LAST_CLOSE` live.
- Historical THB records stay truthful.
- Manual Override remains highest priority.
- Native valuation path must fail closed.
- No automated trade execution unless explicitly added as a new scope.
- MVP-first: do not reopen enterprise-scale work without a real need.

## Suggested next-chat execution order

1. Read this handover first.
2. Read `AGENTS.md`, `contracts/system-contract.yaml`, `VERSION`, and the latest Phase-1 roadmap.
3. Re-read PR #49, #50, #51 states and latest CI.
4. Merge the remaining stack toward `main` only if explicitly authorized in that chat.
5. Verify main contains the merged code/migrations/docs.
6. Clean contradictory documentation.
7. Investigate the legacy CoinGecko Sheet writer.
8. Observe scheduled E2E for 1–2 real US sessions.
9. Continue Focused Dashboard MVP after the pricing path is stable.

## Copyable kickoff prompt for the next chat

Continue FWIOS Phase-1 from:
`docs/implementation/POST_PR52_HANDOVER_TO_NEXT_CHAT_20261017.md`

Current state:
- PR #52 is already merged into PR #51 branch at merge commit `ea5c99414cf430f7613279b42bbc046b8e659800`.
- PR #51/#50/#49 remain open Draft stacked PRs; the stack is not yet in `main`.
- Price Data controlled cutover is already active with `AI Integration Config!B21 = FWIOS_NATIVE`.
- Production valuation path is `Supabase → _Market_Data → Price Data → Holdings`.
- Latest post-merge CI for PR51 head passes PR4 mock Edge-core E2E and PR5 Native USD Adapter.
- Do not rewrite Transactions, Cost Basis, realized P&L, quantities or Holdings formulas.
- Keep `auto_trade=false`.

Immediate priority:
1. verify the stacked PR state and, if explicitly authorized, merge #51 → #50 → #49 → main in order;
2. consolidate outdated docs;
3. identify/retire the remaining legacy direct-CoinGecko Sheet writer without breaking rollback;
4. verify 1–2 autonomous US-close E2E sessions;
5. then continue the Focused Dashboard MVP.
