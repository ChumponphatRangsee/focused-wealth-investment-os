# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.10**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M3 COMPLETE / DASHBOARD HANDOFF PASS**

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

## M3.1 Opportunity Ranking
`POL-OPPORTUNITY-RANKING-V1`; 8/8 regressions. PINS Immediate #1; RDDT Value-Wait #1. Value-Wait cannot receive capital.

## M3.2 New-Cash Allocation
`POL-NEW-CASH-ALLOCATION-V1`; 20/20 regressions. New cash first; Stock Immediate candidates only; max one deployed asset/run; starter cap 5% post-money; residual cash held; no portfolio mutation.

## M3.3 Portfolio Scenario Simulation
`POL-PORTFOLIO-SCENARIO-V1`; 28/28 regressions. NO_SELL / SOFT_REBALANCE / ACTIVE_REBALANCE. ADD traces to active ranking + Decision Snapshot. TRIM must be a current holding with explicit economic/risk rationale. Appreciation-only rationale is forbidden.

## Holding-valuation coverage
`fwios.v_holding_valuation_coverage_current` allows a current holding to supply expected-return lineage from a fresh production valuation. Uncovered holdings are excluded, never proxied.

Reference NVDA route: `SEMIS_MIDCYCLE_DCF_V1::1.0` / `VAL-NVDA-SEMIS-20260905`, model regression PASS. This enables changed-assets NVDA↔PINS expected-return comparison while full portfolio expected-upside remains fail-closed for uncovered risk assets.

## M3.4 Rebalancing Recommendation
Policy `POL-REBALANCE-V1`; 12/12 regressions PASS.

Private snapshot objects:
- `fwios.rebalancing_recommendation_runs`
- `fwios.rebalancing_recommendation_actions`
- `fwios.rebalancing_recommendation_metrics`
- `fwios.preview_rebalancing_recommendation_v1(...)`
- `fwios.materialize_rebalancing_recommendation_snapshot_v1(...)`

M3.5 makes materialized recommendation rows immutable. Production rule remains new-cash-first; trim requires a current valuation-covered concentrated holding and >=25pp PW opportunity edge. 30% is a review threshold, not a forced target.

## M3.5 Human Approval / Cutover
Policy `POL-HUMAN-APPROVAL-V1`; **30/30 regressions PASS**.

### Private objects
- `fwios.human_approval_packets`
- `fwios.human_approval_events`
- `fwios.m3_cutover_validations`
- `fwios.v_human_approval_current`

Architecture:
```text
Rebalancing Recommendation Snapshot [immutable]
                  ↓
          Approval Packet [immutable]
                  ↓
         Approval Event [append-only]
```

Only `PRODUCTION_USER_REQUESTED` is approvable. Approval-time freshness, fingerprint, portfolio-batch, ranking and changed-asset valuation lineage are revalidated. APPROVED/REJECTED require HUMAN actor; EXPIRED/STALE require SYSTEM actor and are terminal. Approval events enforce `broker_order_created=false` and `portfolio_mutation_applied=false`.

Cutover traceability is **9/9 PASS**, with 29/29 transactions and 16/16 positions reconciled. Validation objects remain non-actionable.

## Dashboard Read Model v1 — PASS / LIVE
The post-M3 monitoring architecture is now:
```text
Supabase System of Record
        ↓
Private security-invoker Dashboard Read Models
        ↓
Controlled Snapshot Export
        ↓
Focused Wealth Dashboard - Chumponphat
```

### Stable read models
- `fwios.v_dashboard_holdings`
- `fwios.v_dashboard_account_summary`
- `fwios.v_dashboard_opportunities`
- `fwios.v_dashboard_current_action`
- `fwios.v_dashboard_alerts`
- `fwios.v_dashboard_system_health`

All six views are private `security_invoker` views; `public`, `anon`, and `authenticated` privileges are revoked. Dashboard regression parity is **17/17 PASS**. Security Advisor shows no new WARN/ERROR; only existing private-schema `rls_enabled_no_policy` INFO notices remain.

### Monitoring Sheet
Google Sheet: **Focused Wealth Dashboard - Chumponphat**  
Sheet ID: `17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`

Surface:
- visible `Dashboard` tab
- hidden `_Data` snapshot tab
- Account View selector: All Accounts / Best / Loan Money / Mom
- KPI cards: Portfolio Value / Total P&L / Unrealized P&L / Realized P&L
- consolidated Phase-1 goal, largest position and crypto exposure
- Current Action state
- Opportunity board
- account-filtered Holdings
- consolidated Attention/guardrail alerts
- compact System health

### Account filter boundary
Account View changes display-only portfolio/account fields:
- Portfolio Value
- Total P&L
- Unrealized P&L
- Realized P&L
- Holdings

It **does not** change production risk or decision context. Concentration, crypto exposure, Portfolio Fit and rebalancing always use consolidated exposure.

Total P&L semantics are fixed as:
`latest-batch realized P&L + current open-position unrealized P&L`.

### Sheet logic boundary
Google Sheets may use display/filter/format formulas such as XLOOKUP/FILTER/SORT. It must not calculate production scoring, valuation gates, allocation, scenario, rebalancing or approval policy. Those remain authoritative in Supabase/GitHub.

### Refresh boundary
The current integration is **CONTROLLED_SNAPSHOT_EXPORT**. It is not a direct real-time database connection. The Dashboard always displays source batch/as-of status. A later refresh workflow must be implemented and regression-verified before describing the Sheet as real-time/live-connected.

## Legacy compatibility boundary
The new monitoring Sheet is now the preferred monitoring surface. Legacy Sheets remain available for audit/reconciliation and research continuity. Their reduction is allowed after handoff, but deletion/restructuring should happen only after the controlled refresh workflow and retained audit access are explicitly verified.

## Security
`fwios` remains private. RLS is defense-in-depth and `anon`/`authenticated` privileges are revoked. Dashboard views use SECURITY INVOKER semantics. Security Advisor after the dashboard migration shows no new WARN/ERROR attributable to the change; expected private-schema `RLS Enabled No Policy` INFO notices remain.

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
- controlled snapshot export must not be called real-time;
- human execution only.

## Next architecture action
**Verify controlled Supabase → Google Sheet refresh workflow, then plan legacy-surface reduction.** Financials remains queued; sector automation stays paused while this explicit post-M3 priority is active.

See `policies/rebalancing/REBALANCE_V1.md`, `policies/approval/HUMAN_APPROVAL_V1.md`, and `tests/dashboard/test_post_m3_dashboard_read_models_v1.sql`.
