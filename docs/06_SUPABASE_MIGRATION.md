# Supabase Migration — Focused Wealth Investment OS

Status: **M2 PASS / M3.1–M3.5 LIVE / M3 CUTOVER PASS**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.9`

## Authority
- Supabase = System of Record / State
- GitHub = System of Logic / Contracts / Tests / Migrations
- Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export

## Portfolio state
29/29 transactions and 16/16 source positions reconciled. Current value ~THB 340,906.10; 10 open assets; NVDA ~41.25%; crypto ~38.09%. These are review flags, not automatic sell instructions.

## M2 Decision Intelligence — PASS
Revision/Chase active; 16/16 regressions. PINS Promotion PASS; RDDT Value-Wait due Mispricing FAIL.

## M3.1 Opportunity Ranking — PASS / LIVE
`POL-OPPORTUNITY-RANKING-V1`; 8/8 regressions. `OPPRANK-M3-20260905-01`: PINS Immediate #1; RDDT Value-Wait #1.

## M3.2 New-Cash Allocation — PASS / LIVE
`POL-NEW-CASH-ALLOCATION-V1`; 20/20 regressions. New cash first, Stock Immediate candidates only, max one deployed asset/run, new-position cap 5% post-money, residual cash held, no mutation.

## M3.3 Portfolio Scenario — PASS / LIVE
`POL-PORTFOLIO-SCENARIO-V1`; 28/28 regressions. NO_SELL / SOFT_REBALANCE / ACTIVE_REBALANCE. Preview functions are non-mutating and fail closed on missing changed-asset valuation.

## M3.4 Holding valuation coverage + Rebalancing — PASS / LIVE
`SEMIS_MIDCYCLE_DCF_V1::1.0` provides production NVDA expected-return lineage through `VAL-NVDA-SEMIS-20260905`. `POL-REBALANCE-V1` is ACTIVE with **12/12 PASS**.

Rebalance remains new-cash-first. Trim requires a current valuation-covered concentrated holding, >=25pp PW expected-return edge and remaining approved candidate capacity. 30% is a review threshold, not a forced target. Appreciation-only rationale is forbidden.

## M3.5 Human Approval / Cutover — PASS / LIVE
Policy `POL-HUMAN-APPROVAL-V1`; regressions **30/30 PASS**.

### New private objects
- `human_approval_packets`
- `human_approval_events`
- `m3_cutover_validations`
- `v_human_approval_current`

Recommendation snapshot rows are also protected by immutable UPDATE/DELETE guards once materialized.

### Functions
- `recommendation_snapshot_fingerprint_v1(...)`
- `recommendation_traceability_gate_v1(...)`
- `materialize_rebalancing_recommendation_snapshot_v1(...)`
- `materialize_human_approval_packet_v1(...)`
- `human_approval_packet_integrity_gate_v1(...)`
- `human_approval_revalidation_gate_v1(...)`
- `human_approval_transition_v1(...)`
- `record_human_approval_event_v1(...)`
- `m3_5_traceability_layers_v1(...)`

All functions are SECURITY INVOKER, pin `search_path` to `pg_catalog, fwios`, and are revoked from `anon` / `authenticated` where applicable.

### State model
`Recommendation Snapshot (immutable) → Approval Packet (immutable) → Approval Event (append-only)`.

Only `PRODUCTION_USER_REQUESTED` packets are approvable. `CUTOVER_VALIDATION` and `SYNTHETIC_TEST` are non-actionable and approval attempts are rejected.

APPROVED requires human actor + approval-time revalidation of fingerprint, portfolio batch, active ranking and fresh changed-asset price/valuation lineage. REJECTED is human-only. EXPIRED/STALE are system-only. All are terminal; stale/expired inputs require a new packet.

Approval events enforce:
- `broker_order_created=false`
- `portfolio_mutation_applied=false`

There is no broker/order mutation in the M3.5 approval path.

### Cutover validation
Reference non-actionable fixture:
- recommendation `REBAL-M3-CUTOVER-20260905-01`
- approval packet `APPROVAL-M3-CUTOVER-20260905-01`

Traceability layers = **9/9 PASS**:
1. 29/29 source transactions reconciled
2. 16/16 source positions reconciled
3. portfolio batch PASS
4. PINS Decision Snapshot lineage PASS
5. Opportunity Ranking lineage PASS
6. NVDA holding valuation lineage PASS
7. immutable recommendation fingerprint PASS
8. immutable approval packet PASS
9. execution isolation PASS

Additional cutover invariants:
- production-user recommendation runs = 0
- human approval events = 0
- allocation runs = 0
- scenario runs = 0
- system events = 0
- portfolio total remains reconciled at ~THB 340,906.10

`CUTOVER-M3-20260905-01` is the pre-GitHub-handshake PASS certificate. A final immutable cutover certificate with the merge SHA is created during cross-system sync.

## Security
Approval/cutover tables use RLS defense-in-depth; anon/authenticated access is revoked. Security Advisor after M3.5 reports no new WARN/ERROR from the new objects. Expected private-schema `RLS Enabled No Policy` INFO notices remain. Reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

## M3 migration exit
**M3 = COMPLETE / CUTOVER PASS.** Supabase now owns authoritative state through Human Approval. Approval still does not equal trade execution; any real trade requires separate human broker action and broker price verification.

## Google Sheet / dashboard handoff
M3 cutover now permits legacy Sheet reduction, but physical cleanup is deferred until the new monitoring dashboard is created and verified. The next step is:
1. create stable Supabase dashboard read models;
2. create a new read-only Google Sheet dashboard consuming those views;
3. verify dashboard parity / freshness / approval-state visibility;
4. reduce old Sheet tabs to required research/audit/reconciliation surfaces.

Do not move production scoring, allocation, scenario, rebalance or approval logic into Google Sheets.

Financials remains queued and sector automation remains paused while dashboard/read-model work is the explicit priority.
