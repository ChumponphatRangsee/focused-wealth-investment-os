# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.9**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M2 + M3 COMPLETE / CUTOVER PASS**

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
| Human Approval v1 | **ACTIVE** |

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

Functions:
- `recommendation_snapshot_fingerprint_v1(...)`
- `recommendation_traceability_gate_v1(...)`
- `materialize_human_approval_packet_v1(...)`
- `human_approval_packet_integrity_gate_v1(...)`
- `human_approval_revalidation_gate_v1(...)`
- `human_approval_transition_v1(...)`
- `record_human_approval_event_v1(...)`
- `m3_5_traceability_layers_v1(...)`

### Immutable state model
```text
Rebalancing Recommendation Snapshot
          [immutable]
               ↓
        Approval Packet
          [immutable]
               ↓
        Approval Event
         [append-only]
```

Approvable scope: `PRODUCTION_USER_REQUESTED` only.
`CUTOVER_VALIDATION` and `SYNTHETIC_TEST` are permanently non-actionable.

State semantics:
- APPROVED / REJECTED = HUMAN actor only
- EXPIRED / STALE = SYSTEM actor only
- all four are terminal
- stale or expired state requires a new recommendation/packet; no in-place refresh.

### Approval-time revalidation
APPROVED requires:
1. approval policy ACTIVE;
2. packet PENDING + production-user scope;
3. recommendation fingerprint match;
4. recommendation traceability PASS;
5. unchanged reconciled portfolio batch;
6. unchanged active ranking run;
7. current/fresh candidate Decision Snapshot price;
8. current/fresh production valuation for every changed trim holding;
9. packet freshness deadline not exceeded.

Any failure blocks approval.

### Execution isolation
Approval events are constrained to:
- `broker_order_created = false`
- `portfolio_mutation_applied = false`

Approval does not call a broker connector, create an order or edit the portfolio ledger. Any eventual real trade remains a separate human broker action with price verification.

### Cutover proof
Validation run `REBAL-M3-CUTOVER-20260905-01` and packet `APPROVAL-M3-CUTOVER-20260905-01` are non-actionable. End-to-end traceability = **9/9 PASS**:
- source transactions 29/29
- source positions 16/16
- portfolio batch
- candidate Decision Snapshot
- Opportunity Ranking
- source holding valuation
- immutable recommendation fingerprint
- immutable approval packet
- execution isolation

Cutover also verifies no production-user recommendation, approval event, allocation run, scenario run or system event was created during system activation, and live portfolio value remains reconciled.

## Post-M3 Dashboard Read Model
M3 is complete. Next architecture layer is a read-only experience surface:
```text
Supabase System of Record
        ↓
Stable Dashboard Read Models / Views
        ↓
New Google Sheet Monitoring Dashboard
```

The dashboard may display portfolio state, opportunity ranking, valuation/upside, allocation, rebalancing, approval state, freshness and system health. It must not duplicate production calculations in Sheet formulas.

Legacy Sheets remain available for audit/reconciliation until the new dashboard handoff is verified, after which the old surface may be reduced.

## Security
`fwios` remains private. Approval/cutover tables use RLS defense-in-depth; `anon`/`authenticated` privileges are revoked. Functions are SECURITY INVOKER and pin `search_path=pg_catalog, fwios`. Security Advisor after M3.5 shows no new WARN/ERROR attributable to the changes; expected private-schema `RLS Enabled No Policy` INFO notices remain.

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
- human execution only.

See `policies/rebalancing/REBALANCE_V1.md` and `policies/approval/HUMAN_APPROVAL_V1.md`.
