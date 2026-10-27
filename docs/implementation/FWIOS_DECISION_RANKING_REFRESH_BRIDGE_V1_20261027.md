# FWIOS MVP-1 — Decision / Ranking Refresh Bridge v1

Date: **2026-10-27 Asia/Bangkok**  
Status: **LIVE APPLIED / FAIL-CLOSED / 24-24 ACCEPTANCE PASS**  
Contract baseline: `FWIOS-CONTRACT-0.87.23`  
GitHub baseline inspected: `main@81aba1e3a3ce62520c6b9da11838b1376b0ae531`  
Supabase project: `ysjbmeukwbfnxnwqchuq`  
Live migration: `20261027033605_decision_ranking_refresh_bridge_v1`

## 1. Scope and safety boundary

This slice repaired the stale downstream path after the completed valuation v2 and Quality Hardening refresh:

`current valuation → current mispricing → current hardening → score → Decision Snapshot → Opportunity Ranking audit`.

The bridge did **not** change valuation assumptions, valuation thresholds, mispricing thresholds, Quality Hardening thresholds, core scoring weights, revision/chase thresholds, portfolio-fit thresholds, holdings, transactions, cash, cost basis, approvals or broker execution.

`auto_trade=false`; human execution only.

## 2. Read-only diagnosis

The live audit proved the handover concern was real.

- **ACN** latest Decision/Score still pointed to September upstream state while current production valuation was `VAL-PROD-ACN-ITSERV-V2-20261026` and current hardening was `HARD-QHR-ACN-20261026-7cf9191efa86` = **REVIEW**.
- **EOG** latest Decision/Score also pointed to September upstream state while current valuation was `VAL-PROD-EOG-EP-V2-20261026` and current hardening was `HARD-QCE-EOG-20261026-8094977faaad` = **FAIL**.
- **NFLX** had current valuation/hardening (**REVIEW**) but no canonical Portfolio Fit snapshot, no Decision Score and no Decision Snapshot.
- **PINS** still had historical Decision/Score lineage and a stale Portfolio Fit dependency; its prior ranking-fixture drift is therefore real and remains separate.
- Current Portfolio Fit snapshots for ACN/EOG/PINS point to `PORTFOLIO-M2-20260905-01`, while the current portfolio batch is `PORTFOLIO-MTM-20260924-01`.
- Live `POL-OPPORTUNITY-RANKING-V2` is **RETIRED**, even though older contract/status prose still describes it as active. The 2026-09-24 Opportunity Quality v2 migration retired this policy. This bridge does not silently reactivate it.

Before this repair, current ACN/EOG/NFLX hardening snapshots had no downstream Decision lineage edges. PINS had only historical Decision lineage.

## 3. Implemented bridge

Policy: `POL-DECISION-RANKING-REFRESH-BRIDGE-V1`.

Functions:

- `fwios.preview_decision_refresh_bridge_v1(text)`
- `fwios.apply_decision_refresh_bridge_v1(text, boolean)`
- `fwios.preview_opportunity_ranking_refresh_bridge_v1(text[])`
- `fwios.apply_opportunity_ranking_refresh_bridge_v1(text[], boolean)`

All four functions are invoker-mode, execute is revoked from `public`, `anon`, and `authenticated`, and granted to `service_role` only. APPLY additionally requires explicit `p_human_authorized=true`.

Behavior is deterministic and append-only:

- current production valuation and latest hardening must be aligned;
- score recomputation uses the existing `FWB-DATA-SCORING-V3-DURABILITY` weights and `expected_return_score_v3`;
- existing Business Thesis / Downside score semantics are preserved;
- Revision/Chase snapshots are reused rather than synthesized;
- missing Portfolio Fit blocks the Decision refresh;
- stale Portfolio Fit may produce an **audit Decision only**, with `input_integrity_gate=BLOCKED - STALE PORTFOLIO FIT`; it cannot promote;
- immutable historical Decision/Score rows are not rewritten;
- deterministic IDs make exact repeat APPLY idempotent;
- explicit current valuation/hardening → Decision lineage is written;
- ranking refresh respects the actual lifecycle of `POL-OPPORTUNITY-RANKING-V2`; **RETIRED remains RETIRED**.

## 4. Live result

### ACN

Created:

- Score: `SCORE-DRB-ACN-b8eea53f1b52a486`
- Decision: `DEC-DRB-ACN-b8eea53f1b52a486`
- current valuation: `VAL-PROD-ACN-ITSERV-V2-20261026`
- current hardening: `HARD-QHR-ACN-20261026-7cf9191efa86`

Result:

- Hardening: **REVIEW**
- Decision: `REVIEW - QUALITY HARDENING`
- Core score: `75.1464`
- Expected Return score: `41.9879`
- Promotion: `BLOCKED - QUALITY HARDENING`
- Input integrity: `BLOCKED - STALE PORTFOLIO FIT`
- Revision remains `FAIL - NEGATIVE FUNDAMENTAL REVISION`
- Chase remains `BLOCKED - INCOMPLETE CHASE DATA`

This preserves the required **ACN REVIEW** invariant.

### EOG

Created:

- Score: `SCORE-DRB-EOG-374bad5c8efc68a1`
- Decision: `DEC-DRB-EOG-374bad5c8efc68a1`
- current valuation: `VAL-PROD-EOG-EP-V2-20261026`
- current hardening: `HARD-QCE-EOG-20261026-8094977faaad`

Result:

- Hardening: **FAIL**
- Decision: `FAIL - QUALITY HARDENING`
- Core score: `73.7602`
- Expected Return score: `40.3672`
- Promotion: `FAIL - QUALITY HARDENING`
- Input integrity: `BLOCKED - STALE PORTFOLIO FIT`

This preserves the required **EOG FAIL** invariant.

### NFLX

No Score or Decision was created.

Preview/apply fail closed with:

`PORTFOLIO_FIT_SNAPSHOT_MISSING`

Current hardening remains **REVIEW** on `HARD-QCE-NFLX-20261026-2d4df8695276`.

This preserves **NFLX REVIEW** and avoids inventing a Portfolio Fit snapshot from the legacy scalar field.

### PINS

No new Decision was created by this slice.

PINS still has:

- current hardening **REVIEW**;
- historical Decision `DEC-PINS-REFRESH-20260911`;
- stale Decision lineage;
- stale Portfolio Fit batch.

The known `QH-08 PINS production bucket` drift remains a separate reconciliation problem and was not hidden by changing Quality Hardening.

## 5. Opportunity Ranking audit refresh

Created deterministic audit run:

`OPPRANK-DRB-800010edd38342f5`

Current portfolio batch: `PORTFOLIO-MTM-20260924-01`.

Because `POL-OPPORTUNITY-RANKING-V2` is actually **RETIRED**, the bridge did not reactivate it. The run persisted auditable excluded rows:

| Ticker | Decision lineage | Portfolio Fit | Bucket | Eligibility |
| --- | --- | --- | --- | --- |
| ACN | current PASS | stale | EXCLUDED | BLOCKED - RANKING POLICY RETIRED |
| EOG | current PASS | stale | EXCLUDED | BLOCKED - RANKING POLICY RETIRED |
| PINS | stale | stale | EXCLUDED | BLOCKED - RANKING POLICY RETIRED |
| NFLX | Decision missing | Fit missing | no candidate row | blocked in preview |

`fwios.v_opportunity_ranking_current` remains **0 rows**. Downstream new-cash/scenario/rebalance paths therefore remain fail-closed.

## 6. Idempotency and acceptance

Exact repeat APPLY:

- ACN → `NOOP_ALREADY_REFRESHED`
- EOG → `NOOP_ALREADY_REFRESHED`
- ranking → `NOOP_ALREADY_REFRESHED`

Live regression: **24/24 PASS**.

The regression verifies current valuation/hardening linkage, ACN REVIEW, EOG FAIL, NFLX REVIEW + missing-fit block, ranking V2 still RETIRED, the audit ranking run, zero visible ranking candidates, hardening→Decision lineage, protected row counts and `auto_trade=false`.

Protected counts were unchanged:

- `portfolio_transactions = 58`
- `portfolio_source_positions = 32`
- `portfolio_live_holdings_rows_v1 = 15`
- `portfolio_accounts = 3`
- `human_approval_packets = 1`
- `human_approval_events = 0`

Current scoring weights are unchanged at **30% / 30% / 25% / 15%**. Quality Hardening policy configuration is unchanged.

## 7. Advisor check

Post-DDL Supabase security/performance advisors were run. The bridge introduces no table/index surface and its functions are service-role-only. Advisor output continues to include the repository's existing broad RLS-without-policy INFO backlog and existing unindexed-FK / unused-index performance notices; these were not modified in this slice.

Reference: https://supabase.com/docs/guides/database/database-linter

## 8. Remaining blockers / next step

The stale Decision lineage blocker is repaired for ACN/EOG. The next blockers are now explicit:

1. **Portfolio Fit freshness:** define and implement the minimum deterministic Portfolio Fit refresh from the current portfolio batch. ACN/EOG/PINS cannot become current ranking inputs while their fit snapshots remain on `PORTFOLIO-M2-20260905-01`. NFLX needs a canonical fit snapshot before any Decision refresh.
2. **Ranking lifecycle reconciliation:** resolve the contract/status mismatch where docs still describe `POL-OPPORTUNITY-RANKING-V2` as active while live policy lifecycle is RETIRED after Opportunity Quality v2. Do not reactivate it incidentally; choose the intended production read path explicitly and regression-test downstream allocation/scenario/rebalance before any lifecycle cutover.
3. **NFLX Revision/Chase/base-score chain:** after a valid Portfolio Fit exists, verify missing Revision/Chase inputs and only then construct Decision state.
4. **PINS ranking drift:** reconcile the historical ranking fixture independently. Do not change hardening thresholds to make `QH-08` pass.

No trade or portfolio mutation is authorized by this receipt.
