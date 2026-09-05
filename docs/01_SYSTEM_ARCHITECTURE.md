# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.8**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M2 + M3.1 + M3.2 + M3.3 + M3.4 LIVE**

## Authority model
- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export**

AI may research, interpret, explain and orchestrate within policy. Accounting, scoring, ranking, allocation, scenario and rebalancing math are deterministic/system-controlled. Human execution only.

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
                 Human Approval
```

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
| Rebalance v1 | **ACTIVE** |

## M3.1 Opportunity Ranking
`POL-OPPORTUNITY-RANKING-V1`; 8/8 regressions. Priority = existing Core Score, no second weighted score. PINS Immediate #1; RDDT Value-Wait #1. Value-Wait cannot receive capital.

## M3.2 New-Cash Allocation
`POL-NEW-CASH-ALLOCATION-V1`; 20/20 regressions. New cash first; Stock Immediate candidates only; max one deployed asset/run; new-position starter cap 5% post-money; residual cash held; no portfolio mutation.

## M3.3 Portfolio Scenario Simulation
`POL-PORTFOLIO-SCENARIO-V1`; 28/28 regressions. Modes: `NO_SELL`, `SOFT_REBALANCE`, `ACTIVE_REBALANCE`. Every ADD traces to active ranking + Decision Snapshot. Every TRIM must target a current holding, remain within value and carry explicit economic/risk rationale. Appreciation-only rationale is forbidden. Full portfolio expected upside fails closed when risk-asset valuation coverage is incomplete.

### Holding-valuation coverage bridge
M3.4 adds `fwios.v_holding_valuation_coverage_current` so a current holding may supply expected-return lineage from a fresh production valuation even when it has no candidate Decision Snapshot. Requirements:
- valuation model version = PRODUCTION and regression PASS;
- valuation run = production eligible / valuation PASS / schema PASS;
- run price snapshot = current fresh market snapshot with effective price gate PASS;
- current portfolio exposure must contain the asset.

Uncovered holdings are excluded, never proxied.

## Semiconductor Designer valuation v1
`SEMIS_MIDCYCLE_DCF_V1::1.0` is production-live using a deterministic five-year equity-FCF DCF + terminal value.

Required normalized inputs:
`revenue_ltm`, `gross_margin`, `inventory_days`, `customer_concentration`, `fcf_ltm`, `net_cash`, `shares_outstanding`, plus signed pending acquisition consideration where applicable.

NVDA production snapshot `VAL-NVDA-SEMIS-20260905`:
- price `PX-NVDA-20260904` = $230.34;
- FCF LTM $127.006B;
- conservative net cash $23.220B;
- pending Hugging Face purchase consideration $11.9B deducted from equity bridge;
- Bear / Base / Bull / PW FV = 87.03032203 / 166.16708908 / 273.20947981 / 173.14349500;
- `REG-SEMIS-V1-NVDA-PARITY` PASS.

This enables NVDA↔PINS changed-assets expected-return comparison. Full portfolio expected-upside coverage remains incomplete because other risk assets are not yet valuation-covered.

## M3.4 Rebalancing Recommendation
Policy `POL-REBALANCE-V1`; 12/12 regressions PASS.

New private snapshot objects:
- `fwios.rebalancing_recommendation_runs`
- `fwios.rebalancing_recommendation_actions`
- `fwios.rebalancing_recommendation_metrics`
- `fwios.preview_rebalancing_recommendation_v1(...)`

Deterministic v1 flow:
```text
New cash
   ↓ first
Immediate candidate capacity
   ↓ remaining capacity
Covered concentrated holding (>30%)
   + PW expected-return edge >= 25pp
   ↓
trim = min(remaining candidate capacity, concentration excess)
   ↓
M3.3 changed-assets scenario / expected-value delta
   ↓
READY - HUMAN REVIEW
```

Invariants:
1. New cash is used before a trim.
2. ADD candidate must be active Immediate + Decision Snapshot valuation lineage.
3. Trim source must be current, valuation-covered and concentration-review eligible in v1.
4. Trim is never larger than approved remaining candidate capacity.
5. 30% is a review threshold, not a forced target.
6. Appreciation alone cannot justify a trim.
7. Full-portfolio valuation coverage is not required for a changed-assets comparison when every changed non-cash asset is covered.
8. Preview/recommendation activation does not mutate holdings or place orders.
9. Broker price verification + explicit human approval are required before any real trade.

Synthetic parity:
- new cash 0 → NVDA trim ~17,045.30 → PINS add ~17,045.30;
- new cash 10k → 10k new cash first + NVDA trim ~7,545.30;
- new cash 50k → PINS starter capacity funded from cash, NVDA trim 0.

These are regression examples, not trade instructions. No production recommendation run is materialized by policy activation.

## M3.5 Human Approval / Cutover boundary
Next layer must create immutable approval/rejection/expiry state and revalidate price/valuation freshness before approval. Approval itself must never submit a broker order or mutate portfolio accounting. M3 cutover passes only with end-to-end traceability from ledger transaction/position through recommendation and human decision.

## Google Sheets
During M3.2–M3.5, write only `System_Foundation` / audit status. No production scoring, allocation, scenario or rebalancing logic/config is authored in Sheet tabs.

## Security
`fwios` remains private. New recommendation tables use RLS defense-in-depth; `anon`/`authenticated` privileges are revoked. New view/functions are security-invoker and pin search path. Security Advisor after M3.4 shows no new WARN/ERROR attributable to these changes; expected private-schema `RLS Enabled No Policy` INFO notices remain.

## Architectural invariants
- live reconciled state outranks stale docs;
- missing/stale/unverified critical inputs fail closed;
- no candidate can bypass hard gates;
- uncovered holdings cannot be economic trim sources;
- no hidden score/valuation proxy is invented;
- new cash precedes trim logic;
- no force-fill;
- scenario/recommendation outputs never mutate live holdings;
- human execution only.

See `policies/valuation/SEMIS_MIDCYCLE_DCF_V1.md` and `policies/rebalancing/REBALANCE_V1.md`.
