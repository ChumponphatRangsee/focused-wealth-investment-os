# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.10**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M3 COMPLETE / DASHBOARD AUTO REFRESH LIVE**

## Authority model
- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export**

AI may research, interpret, explain and orchestrate within policy. Accounting, scoring, ranking, allocation, scenario, rebalancing and approval gates are deterministic/system-controlled. Human execution only.

## Decision-and-capital architecture
```text
Source / Evidence / Canonical Facts / Normalized Metrics
                         ↓
                    Valuation
                         ↓
         Market Price + Portfolio State/Fit
                         ↓
       Core Score + Revision / Chase Gates
                         ↓
                 Decision Snapshot
                         ↓
               Opportunity Ranking
                         ↓
              New-Cash Allocation
                         ↓
          Portfolio Scenario Simulation
                         ↓
           Rebalancing Recommendation
                         ↓
                Approval Packet
                         ↓
               Approval Event
                         ↓
           Separate Human Broker Step
```

Approval is an audit/state boundary, not a broker execution layer.

## Production policy state
| Policy | State |
|---|---|
| Data Scoring 30/30/25/15 | ACTIVE |
| Mispricing | ACTIVE |
| Portfolio Fit | ACTIVE |
| Revision Score v1 | ACTIVE |
| Chase Risk v1 | ACTIVE |
| Opportunity Ranking v1 | ACTIVE |
| New-Cash Allocation v1 | ACTIVE |
| Portfolio Scenario v1 | ACTIVE |
| Rebalance v1 | ACTIVE |
| Human Approval v1 | ACTIVE |

## M3 summary
- M3.1 Opportunity Ranking: `POL-OPPORTUNITY-RANKING-V1`, 8/8 PASS.
- M3.2 New-Cash Allocation: `POL-NEW-CASH-ALLOCATION-V1`, 20/20 PASS.
- M3.3 Portfolio Scenario: `POL-PORTFOLIO-SCENARIO-V1`, 28/28 PASS.
- M3.4 Rebalancing Recommendation: `POL-REBALANCE-V1`, 12/12 PASS.
- M3.5 Human Approval: `POL-HUMAN-APPROVAL-V1`, 30/30 PASS.
- M3 overall: **COMPLETE / CUTOVER PASS**.

`SEMIS_MIDCYCLE_DCF_V1::1.0` / `VAL-NVDA-SEMIS-20260905` supplies traceable NVDA holding expected-return coverage. Uncovered holdings are excluded, never proxied. Changed-assets NVDA↔PINS comparison is supported; full-portfolio expected-upside remains fail-closed until coverage is complete.

Human Approval architecture remains:
```text
Rebalancing Recommendation Snapshot [immutable]
                  ↓
          Approval Packet [immutable]
                  ↓
         Approval Event [append-only]
```
Only `PRODUCTION_USER_REQUESTED` is approvable. Approval never creates a broker order or mutates portfolio accounting.

## Dashboard Read Model v1 — PASS / LIVE
Stable private `security_invoker` views:
- `fwios.v_dashboard_holdings`
- `fwios.v_dashboard_account_summary`
- `fwios.v_dashboard_opportunities`
- `fwios.v_dashboard_current_action`
- `fwios.v_dashboard_alerts`
- `fwios.v_dashboard_system_health`

Dashboard read-model regression parity: **17/17 PASS**.

### Monitoring Sheet
Google Sheet: **Focused Wealth Dashboard - Chumponphat**  
Sheet ID: `17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`

Surface:
- visible `Dashboard` tab;
- hidden `_Data` tab;
- Account View: All Accounts / Best / Loan Money / Mom;
- KPI cards: Portfolio Value / Total P&L / Unrealized P&L / Realized P&L;
- consolidated Phase-1 goal, largest position and crypto exposure;
- Current Action, Opportunity board, account-filtered Holdings, consolidated Alerts and compact System health.

Account View changes only Portfolio Value, P&L and Holdings display. Concentration, crypto exposure, Portfolio Fit and rebalancing always use consolidated portfolio exposure.

Google Sheets may use display/filter/format formulas only. It must not calculate production scoring, valuation gates, allocation, scenario, rebalancing or approval policy.

## Dashboard Auto Refresh v1 — PASS / LIVE
The monitoring architecture is now:
```text
Supabase System of Record
        ↓
6 private dashboard read models
        ↓
fwios.dashboard_refresh_payload_v1()
        ↓
Supabase Edge Function: dashboard-refresh-csv-v1
        ↓
Google Sheets IMPORTDATA
        ↓
hidden _Data tab
        ↓
Dashboard display formulas
```

### Database objects
- `fwios.dashboard_refresh_access`
  - private token registry;
  - stores SHA-256 hash only, never the raw token.
- `fwios.dashboard_refresh_cache`
  - one `PRIMARY` last-good payload;
  - used only as fail-safe fallback.
- `fwios.dashboard_refresh_payload_v1()`
  - stable canonical JSON payload assembled from the six dashboard read models;
  - returns `refresh_gate=PASS` only when portfolio reconciliation and execution-safety invariants pass.

The obsolete side-effecting `fwios.dashboard_refresh_serve_v1()` is removed. Google fetch is read-oriented; audit/cache behavior cannot be required for a valid read.

### Edge boundary
`dashboard-refresh-csv-v1` intentionally uses `verify_jwt=false` because Google Sheets IMPORTDATA cannot send a Supabase Authorization header. The function therefore implements custom token authentication and compares the supplied high-entropy token with the private SHA-256 hash in `dashboard_refresh_access`.

The endpoint exposes monitoring CSV only. It has no path to trade execution, portfolio transaction mutation, policy mutation, allocation/scenario materialization, recommendation creation or approval events.

### Fail-closed refresh
1. Read `dashboard_refresh_payload_v1()`.
2. If `refresh_gate=PASS`, serve current payload and best-effort update last-good cache.
3. If current gate is BLOCKED, serve last-good cache with `STALE_BLOCKED`.
4. If no last-good cache exists, return an error rather than fabricate data.

### Google Sheet implementation
- `_Data!A1` contains the IMPORTDATA formula.
- `_Data!T100` contains the read-only Edge feed URL.
- the feed fills a fixed 65×20 matrix matching existing Dashboard formulas.
- `_Data!A61:F62` reports worker, worker id, last checked time, status, fingerprint and refresh gate.
- first-time external-data permission was granted by the Sheet owner on desktop.

### Verification
- static Edge fetch probe PASS;
- Edge environment PASS;
- Edge DB connection PASS;
- access-token lookup PASS;
- canonical payload query PASS;
- final CSV feed PASS;
- `_Data` cutover PASS;
- dashboard KPI/holdings/system parity preserved;
- forced refresh advanced metadata to 2026-09-06 09:30 Asia/Bangkok;
- last-good cache advanced on the same fetch;
- auto-refresh regression suite **14/14 PASS**;
- security advisor: no new WARN/ERROR; expected private-schema `rls_enabled_no_policy` INFO only.

### Refresh semantics
This is **automatic pull refresh**, not push/realtime streaming. Google Sheets controls IMPORTDATA recalculation cadence and background behavior. Therefore:
- `AUTO_REFRESH_LIVE` is accurate;
- `REAL_TIME` or guaranteed `24/7 closed-file refresh` is not accurate.

A future guaranteed closed-file writer would require Apps Script, a service-account worker or another trusted Google-authorized process.

## Legacy compatibility boundary
The new Dashboard is the preferred monitoring surface. Legacy Sheets remain available for audit/reconciliation and research continuity. Reduction is now technically allowed because dashboard handoff and refresh verification are both PASS, but deletion/restructuring still requires an explicit retained-audit plan.

## Security
`fwios` remains private. RLS is defense-in-depth and `anon`/`authenticated` privileges are revoked. Dashboard views use SECURITY INVOKER semantics. Refresh access/cache tables are private and have no anon/authenticated policies. The raw feed token must never be committed to GitHub and should be rotated if the Sheet is shared beyond trusted editors.

## Architectural invariants
- live reconciled state outranks stale docs;
- missing/stale/unverified critical inputs fail closed;
- no candidate bypasses hard gates;
- uncovered holdings cannot be economic trim sources;
- no hidden valuation/score proxy is invented;
- new cash precedes trim;
- no force-fill;
- recommendation and approval snapshots are immutable;
- validation/test packets can never be approved;
- approval cannot place orders or mutate holdings;
- Account View never changes consolidated decision context;
- Dashboard contains no production policy logic;
- auto-refresh transport cannot mutate investment state;
- automatic pull refresh must not be called guaranteed real-time streaming;
- human execution only.

## Next architecture action
**Plan legacy-surface reduction with retained audit/reconciliation access, then decide when to resume Financials sector research.**

See `docs/07_DASHBOARD_AUTO_REFRESH.md`, `tests/dashboard/test_dashboard_auto_refresh_v1.sql`, `tests/dashboard/test_post_m3_dashboard_read_models_v1.sql`, `policies/rebalancing/REBALANCE_V1.md`, and `policies/approval/HUMAN_APPROVAL_V1.md`.
