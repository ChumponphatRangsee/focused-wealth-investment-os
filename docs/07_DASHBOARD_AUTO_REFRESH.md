# Dashboard Auto Refresh v1

Status: **PASS / LIVE**  
Global investment-policy contract: **FWIOS-CONTRACT-0.87.10**  
Implemented: **2026-09-06 Asia/Bangkok**

## Purpose
Keep `Focused Wealth Dashboard - Chumponphat` synchronized with the canonical private Supabase dashboard read models without moving scoring, valuation, allocation, rebalancing, approval, accounting, or trade execution logic into Google Sheets.

## Architecture
```text
Supabase System of Record
        ↓
6 private security-invoker dashboard views
        ↓
fwios.dashboard_refresh_payload_v1()
        ↓
Supabase Edge Function dashboard-refresh-csv-v1
        ↓
Google Sheets IMPORTDATA on hidden _Data tab
        ↓
Dashboard display formulas
```

The Sheet remains downstream/read-only from a production-logic perspective.

## Sheet contract
- Sheet ID: `17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`
- visible tab: `Dashboard`
- hidden tab: `_Data`
- `_Data!A1` contains the IMPORTDATA formula.
- `_Data!T100` contains the read-only Edge URL used by the formula.
- imported matrix size: 65 rows × 20 columns.
- metadata rows `_Data!A61:F62` expose worker, last checked time, status, source fingerprint and refresh gate.

## Security
- Edge Function `dashboard-refresh-csv-v1` intentionally has platform JWT verification disabled because Google Sheets IMPORTDATA cannot send a Supabase Authorization header.
- The function implements custom high-entropy token authentication.
- Supabase stores only the SHA-256 token hash in private table `fwios.dashboard_refresh_access`.
- `anon` and `authenticated` have no access to refresh tables or `fwios.dashboard_refresh_payload_v1()`.
- The feed is read-only and contains dashboard monitoring data only; it cannot mutate portfolio, policies, allocation, scenarios, recommendations, approvals or broker state.
- Anyone with edit access to the hidden `_Data` tab can inspect the feed URL, so the token must be rotated if the Sheet is shared beyond trusted editors.

## Fail-closed behavior
`fwios.dashboard_refresh_payload_v1()` returns `refresh_gate=PASS` only when:
- latest portfolio batch status is PASS;
- transaction reconciliation counts match;
- position reconciliation counts match;
- `auto_trade=false`;
- `human_execution_only=true`.

On PASS, the Edge Function serves current payload and best-effort updates `fwios.dashboard_refresh_cache` as the last-good snapshot.

If the current payload gate is BLOCKED, the Edge Function serves the last-good cache with `served_status=STALE_BLOCKED`. If no last-good cache exists, the function returns an error instead of fabricating dashboard data.

## Google refresh boundary
This is **automatic pull refresh**, not push/realtime streaming. Google Sheets controls IMPORTDATA recalculation cadence and background execution behavior. The Dashboard must therefore be described as auto-refreshing, not as a guaranteed real-time market feed.

A future 24/7 push-style refresh while the Sheet is closed would require a Google-authorized writer such as Apps Script, a service account worker, or another trusted automation that can write `_Data` through the Sheets API.

## Verification
Production verification on 2026-09-06:
- first-time external-data permission granted by the Sheet owner;
- Supabase Edge static probe PASS;
- Edge database connection PASS;
- dashboard payload query PASS;
- final Edge CSV feed PASS;
- `_Data` cutover to IMPORTDATA PASS;
- dashboard formulas/holdings/system health remained valid after cutover;
- forced refresh metadata advanced to 2026-09-06 09:30 Asia/Bangkok;
- last-good cache timestamp advanced on the same refresh;
- refresh regression suite: **14/14 PASS**;
- security advisor: no new WARN/ERROR; only expected private-schema `rls_enabled_no_policy` INFO notices.

## Invariants
- Supabase remains System of Record.
- Google Sheets remains a monitoring surface.
- Account View never changes consolidated risk/portfolio-fit/rebalancing context.
- No auto-trade.
- No portfolio mutation.
- No scoring/valuation/allocation/rebalance/approval logic in the Sheet.
- Token values are never stored in GitHub.
