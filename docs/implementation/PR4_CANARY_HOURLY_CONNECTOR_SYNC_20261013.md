# FWIOS PR4 — Hourly authenticated-connector snapshot sync

**Implemented:** 2026-10-13 (Asia/Bangkok)  
**Scope:** Current canonical quotes only; no vendor API or portfolio ledger mutation.  
**Status:** **SCHEDULED & ENABLED, MANUAL CONNECTOR ROUNDTRIP PASS; FIRST SCHEDULED EXECUTION PENDING.**

## Connection architecture

```text
ChatGPT recurring task (hourly; enabled)
    ├─ connected Supabase project ysjbmeukwbfnxnwqchuq
    │   └─ SQL SELECT fwios.pr4_market_canary_quote_v2(asset)
    │       BTC / NVDA / TTWO / USDTHB (existing observations ONLY)
    └─ connected Google Drive / Google Sheets
        └─ existing spreadsheet Focused Wealth Dashboard - Chumponphat
            └─ PR4 Canary Snapshot!A3 and A6:L9
```

- No JWT or service-role credential copied to Google Sheets or GitHub.
- No Supabase Edge HTTP calls, real provider HTTP, quota reservations or retries.
- Does not change the 8 legacy Supabase cron jobs. Does not re-enable the
  older **Dashboard Market Sync** automation, which remains disabled and
  controls the separate `_Data` portfolio surface.
- No standalone app or user Supabase Auth account is required for this
  connector-to-connector reporting path.
- **Hourly snapshot, not real-time streaming.** At-capture freshness status
  must not be represented as the current quote status outside that timestamp.

## Fixed destination

Spreadsheet: `17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`  
Tab: `PR4 Canary Snapshot`, `sheetId=1579369903`

Only two write requests, in one `batch_update_spreadsheet`:
- `A3`: update last-read timestamp in UTC with explicit warning that the
  sheet is a snapshot.
- `A6:L9`: four data rows in order BTC, NVDA, TTWO, USDTHB. Columns:
  asset, price as numeric, currency, quote kind, status with
  `(at capture)` suffix, provider, session date, observed UTC, captured
  UTC, valid-until UTC, accounting eligible `NO`, observation ID.

All surrounding user-entered formatting, notes, other sheets and rows
(including Dashboard, `_Data`, Transactions, Holdings, Price Data, Tracker,
and Screener) are never modified by this job.

## Scheduled safety gate

Each run must:

1. Read all four prices in **one** Supabase SQL SELECT using the existing
   `fwios.pr4_market_canary_quote_v2` service role-only database function.
   Do not touch Supabase provider HTTP, scheduler or usage tables.
2. Require canonical asset symbols, correct quote kinds/currencies, positive
   prices, exact allowlisted statuses, all three accounting/valuation/trading
   eligibility flags `false`, canary_only and read_only flags `true`,
   origin `EXISTING_CANONICAL_OBSERVATION`, and the new-provider-call /
   quota-reservation fields equal zero. `STALE` is accepted as a correctly
   labeled display but **never** treated as usable valuation.
3. Inspect destination metadata and the exact row-5 header/sheet ID before
   writing. Any drift means **no write**.
4. Write only `A3` and `A6:L9` with `userEnteredValue` field masks
   (no formula or formatting changes).
5. Re-read those specific cells and verify price, timestamps, asset order,
   statuses, and zero accounting eligibility; failed verification is not PASS.
6. On missing connectors, invalid data, permissions problems, unexpected
   schema or writeback mismatch, stop. Do not try anonymous fallback, vendor
   API, unguarded Edge access or secret injection.

Owner can pause or disable the ChatGPT task named **FWIOS PR4 Canary Sync**
in their Tasks settings; it has no Supabase cron job to remove. The task runs
at **hourly** frequency, with flexible timing. Existing portfolio tasks are
independent and remain as previously configured.

## Initial verified source-to-sheet roundtrip

At **2026-10-13 08:12:56 UTC**, one connected tool execution:
- Read canonical BTC: **2,812,349 THB**, `FRESH` at capture;
- NVDA: **226.32001 USD**, `LAST_CLOSE`;
- TTWO: **208.82001 USD**, `LAST_CLOSE`;
- USDTHB: **33.62546**, `STALE`, attached FX reference.

The single Google Sheets batch successfully updated `A3` and `A6:L9`;
Google Sheets connector readback verified four rows, provider, timestamps,
observation IDs, status and numeric values.

After enabling the recurring task, separately updated tab notes in
`A2`, `A11`, `A12`, `A14` to say *hourly snapshots*, and verified those
notes from Google Sheets. No secret-bearing URL was stored.

**Important:** the initial source-to-sheet roundtrip was manually triggered.
It does NOT prove that the recurring task's next independent run will succeed.
Check its execution outcome and the `A3` timestamp after the first scheduled
invocation before marking automated recurring execution PASS.

## Release scope

PR #49/#50/#51 stay draft/unmerged, provider-dispatch cutover OFF, eight
production cron jobs unchanged. No transaction, holdings, accounting, 
portfolio valuation or API quota write. The existing market observation
writers may continue recording canonical prices on their already-active
schedule; this task only reads them.

Never make `LAST_CLOSE` prices or attached `USDTHB` FX an authoritative
portfolio mark-to-market input through this display.
