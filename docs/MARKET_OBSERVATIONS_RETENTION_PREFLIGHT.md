# Market observations retention & cleanup — read-only preflight (2026-10-30)

**Status:** PREPARED / NOT APPROVED FOR DELETE. This plan does not reset data or alter production. It deliberately has no DELETE SQL or destructive migration.

## Context and live baseline

- Source: live Supabase `ysjbmeukwbfnxnwqchuq`, repo `main` SHA `7b09dc837ac9fff426a8f6f14f1d79c1e74ed2d4`, Investment Portfolio Tracker `_Market_Data`.
- 10 active held assets (BTC/DOGE/ETH/HBAR/SOL/XRP, MSFT/NVDA/TLN/TTWO), 18,659 `fwios.market_observations` rows, ~18 MB including indexes.
- Provider sources of current table: CoinGecko LIVE_QUOTE 13,338; Twelve Data FX 2,572; Twelve Data stock LIVE_QUOTE 2,486; all other sources together 263.
- Live current canonical read `fwios.pr7_native_usd_price_read_v1` selected 10/10 observation UUIDs, and all 10 match `_Market_Data` observation IDs (2026-10-30 readback).
- `market_observations_append_only` trigger is enabled. Zero inbound PostgreSQL FKs **does not** prove zero downstream dependencies. The Sheet and Edge code explicitly use `observation_id`.
- `raw_payload` is not uniformly object-shaped: 858 COINGECKO rows and 4 FRANKFURTER_FX rows are JSONB **strings**, while other newer/old records are JSONB objects. Do not equate `raw_payload->>'price_only'` null with safe-to-delete. In the tightened 2026-10-30 policy, any non-object JSONB payload not already protected is MANUAL_REVIEW_JSON_PAYLOAD, never an archive candidate. Protect current references and provider/type regardless.
- **EOD blocker:** Cron #17 and #18 are scheduled but had no natural run at preflight time. Certified price-only Stock EOD observations = 0, Alpha Vantage recent test HTTP 503 quota error; four Sheet Stock rows were still from session 2026-10-28. See issue #106.

## Classification simulation, not deletion authority

Read-only report file: `tests/price/market_observations_retention_preflight_20261030.sql`. Repeatable projection assertions: `tests/price/test_market_observations_retention_projection_20261030.sql` (21/21 PASS against live 2026-10-30 data, SQL SELECT/CTE only; no isolated physical branch or DELETE test).

| Rule bucket | 2026-10-30 count | Meaning |
|---|---:|---|
| `KEEP_PROTECTED` | 234 | Selected canonical UUIDs, every REGULAR_CLOSE, provider ALPHA_VANTAGE_PRICE / FRANKFURTER_FX, explicit price-only provenance |
| `KEEP_RECENT` | 1,021 | Other object-payload rows created within 14 days |
| `KEEP_DAILY_SAMPLE` | 256 | Latest row by asset/provider/type/session for older CoinGecko/Twelve Data streams |
| `ARCHIVE_REVIEW_ONLY` | 16,283 | Older superseded object-payload intraday candidates; NOT verified safe to purge |
| `MANUAL_REVIEW_JSON_PAYLOAD` | 852 | JSONB strings or non-objects not covered by other protected rules: cannot trust direct JSONB flag extraction |
| `MANUAL_REVIEW` | 13 | Anything not covered |
| **TOTAL** | **18,659** | Classification changes as `now()` advances |

Do not interpret duplicate-in-day intraday observations as byte-identical duplicates: prices at different times may differ and observation keys are all unique. A once-per-day sample does not equal a certified official closing price. No backfilling with approximations.

## Mandatory gating sequence (FAIL CLOSED)

1. **EOD first:** issue #106 current-session Alpha Vantage `US_STOCK_EOD` collector Cron #17 actual HTTP 200 with 4 certified rows, sheet sync Cron #18 actual HTTP 200, stock_count=4 and readback verified. Cron dispatcher status is insufficient. No fake stock values; observe next eligible NY close.
2. **Snapshot and lineage:** capture 10 `pr7_native_usd_price_read_v1` output objects, all 10 `_Market_Data` rows and FX S2/FX provenance, Source Audit & Price Data formulas, and exact retained `observation_id` set. Verify Stock Holdings OPEN symbols directly from Sheet at time of execution.
3. **Independent consumer audit:** inspect current GitHub main, two deployed Edge workers, six SQL functions, view, cron jobs, external Sheet formulas and historical evidence consumers. Protect each referenced UUID and any data used as fallback. Disabling the append-only trigger is **not** a routine retention operation.
4. **Backup and restore:** confirm a real backup exists; export complete observation rows (including UUID, observation_key, metadata, provenance and raw_payload) into an access-controlled off-production artifact; verify row count and checksum. Rehearse an isolated restore. Supabase plan/PITR availability and restore capability are not yet verified.
5. **Isolated dry run:** only in a detached copy, run an explicitly reviewed targeted cleanup using a frozen candidate manifest (no moving `now()` cutoff). Verify all current prices, statuses, provider provenance and observation IDs compare to baseline, Google Sheet readback unaffected, USDTHB intact, all regression SQL assertions (previously 44/44 PASS), and zero accounting/trade writes.
6. **Separate execution approval:** get explicit approval for the exact frozen manifest row count and irreversible action. Only then stage a narrow, transactionally guarded, reviewed production procedure, preserving the append-only contract or using an authorized controlled maintenance window. Re-check counts and signed-off backup immediately before execution.
7. **Postflight:** verify results, rerun tests, verify Cron #14–18, update `docs/CURRENT_STATUS.md`, attach receipts to issue/PR, confirm rollback runbook.

## Non-goals and constraints

- No drop/truncate/recreate of `fwios.market_observations`; no clearing `_Market_Data`, no market price forgery, no automatic recalc of Holdings.
- Keep `fwios.instruments` and `fwios.instrument_symbols` unchanged; three core tables, only two active Edge workers; no scanner/research/portfolio backend restoration.
- No Transactions, Holdings, Cost Basis, manual overrides, accounting or portfolio state modification; `auto_trade=false`.
- A small ~18 MB table does not justify production data loss or unnecessary index bloat. Prefer archiving only after all gates pass.

## Rollout receipt

As of this document: read-only SQL simulation completed, 10 canonical references reconciled to Sheet, 21/21 retention-projection assertions PASS (including latest FX, 10 prices/IDs, and fallback history), 44/44 existing Price Service regressions PASS, EOD not certified, **no data deletion, no trigger toggling, no schema changes, no scheduled job changes**.
