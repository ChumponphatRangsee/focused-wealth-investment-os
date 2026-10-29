# FWIOS Scanner Clean Start — User-Directed Reset (2026-10-29)

## Intent and outcome

Owner: **"ลบหุ้นและ Thesis ทุกตัวออกให้หมดก่อน เราจะเริ่มกันใหม่จากการค้นหาหุ้น"**.
Implement an **empty current scanner and zero active thesis/watchlist** so the next phase starts with new stock discovery. **Do not hard-delete canonical stock identities, SEC evidence, historical research/theses, prices, or portfolio data**. Existing foreign keys would either prohibit thesis/instrument deletion or cascade-delete valuable historical evidence. Protect current portfolio accounting and 64-name EOD feed.

**ACTUALLY APPLIED** in Supabase project `ysjbmeukwbfnxnwqchuq` on 2026-10-29 15:42 Asia/Bangkok. Additive reset migration:
`supabase/migrations/20261029154500_scanner_clean_start_archive_theses_v1.sql`.

### Before / after

| Authority / surface | Before | After | Action |
|---|---:|---:|---|
| `fwios.v_scanner_current_v1` | 64 | **0** | View gated by empty new-generation explicit discovery enrollment |
| `fwios.thesis_registry` active | 63 | **0** | Archived by `active=false`, metadata reset marker |
| `fwios.thesis_registry` historical rows | 63 | **63** | Preserved for audit/recovery |
| `fwios.research_candidates` legacy derived research | 27 | **27** | Left intact, not enrolled into new scan |
| `fwios.scanner_discovery_enrollments_v1` | Not present | **0** | Private/RLS enabled, empty new generation |
| `fwios.scanner_reset_batches_v1` | Not present | **1** | Timestamped reset receipt, pre-reset ticker snapshot |
| Stock instruments (active) | 64 | **64** | Identity/portfolio foreign keys untouched |
| US EOD 2026-10-28 verified collection | 64 | **64** | Market history untouched |
| `fwios.portfolio_transactions` | 58 | **58** | No accounting changes |

**Reset ID / generation:** `SCAN-RESET-20261029`. Only new rows in `scanner_discovery_enrollments_v1` with this generation and `active=true` can become visible in `v_scanner_current_v1`. The view still pulls verified price, research and fair-value fields from existing sources for enrolled stocks; future discovery must enforce **fresh-generation analysis eligibility** separately so legacy historical valuations do not automatically become actionable. Merely enrolling an old ticker is NOT proof of a new thesis or validation. Preserve strict fail-closed gates.

### Scheduled operations

Paused **ChatGPT Scheduled Task** `FWIOS TTWO Research Manager` (task `6ae1ca651eb881919456df1b5d35186b`) so it cannot keep recycling the previous TTWO pilot as new research.

Paused these **Supabase Cron jobs** (old research loops, not market EOD):
- Job #2 `fwios-shadow-decision-refresh-worker`
- Job #8 `fwios-shadow-decision-refresh-enqueue`
- Job #9 `fwios-thesis-health-refresh`
- Job #10 `fwios-opportunity-quality-refresh` was already inactive; not altered.

The independently scheduled **64-name market daily close Cron jobs #6 and #7 remain active** so trading/portfolio price history continues, as do Portfolio Cron #14, #15, #16. Do not interpret continuing market price history as an active Scanner watchlist. No automatic trading.

### Verification

Read-only acceptance `tests/scanner/test_scanner_clean_start_20261029.sql`: **19/19 PASS** against live Supabase; includes zero new-generation members, zero active theses, preserved 63 historical theses and 27 legacy research candidates, 58 transactions, 64 stock identities, 64 EOD rows, correct paused/active Cron set, protected table access/RLS. This is **reset-day acceptance**, not a permanent test: the zero active Scanner count is expected to change when new discovery officially starts.

### What is NOT deleted / NOT restarted

- Previous TTWO clean-room draft PR #96, experimental model PR #97, autonomous model PR #98 remain historical draft artifacts, not merged.
- Old valuation/model snapshots, thesis evidence and candidates remain in archival production structures for audit, not as active new-gen Scanner members.
- Individual stock instrument identity and portfolio-held positions are shared operational state; **do not delete or deactivate** them.
- The `v_research_readiness_current_v1` and legacy analytics still enumerate active stock instruments; **the authoritative clean-start Scanner surface** is `v_scanner_current_v1`. Do not pretend all historical research/market/portfolio screens are physically empty.

### New Discovery — follow-on contract (not executed)

1. Define **Discovery Universe** (S&P 500 official membership, sector coverage, exclusion policy), not past Scanner rows.
2. Maintain a **separate new-generation ticker enrollment** with primary-source identity checks and an audit receipt for each discovery decision; do not bulk-reactivate old Thesis rows.
3. Backfill verified OHLCV history as needed for technical signals (RSI/SMA/MACD/ATR). Current EOD close data has limited per-symbol history and lacks OHLCV.
4. Technical shortlisting should be paired with research/valuation and independent backtesting, avoiding point-in-time lookahead. **Never reuse stale pre-reset Fair Values as fresh research.**
5. Set explicit go-live criteria before restarting research Cron jobs, changing scoring/decision policy, or letting Scheduled ChatGPT enroll candidates. `auto_trade=false`, no portfolio accounting mutation.
6. The global approved `FWIOS-CONTRACT-0.87.26` currently says `execution_mode: human_execution_only`. This reset does not override the contract.

### Recovery / rollback

The reset is reversible by metadata, not by restoring database backups. To restore the **prior UI semantics**, review code and change the `v_scanner_current_v1` JOIN to old approved SQL (available from Git history or in the migration rollback design); to restore archived theses, use the reset marker `metadata->>'archived_by_scanner_reset'='SCAN-RESET-20261029'` rather than a blanket UPDATE. Reactivating research Cron jobs or ChatGPT schedules also requires a separate owner decision; do not silently restart the previous workflows. No hard deletes performed.
