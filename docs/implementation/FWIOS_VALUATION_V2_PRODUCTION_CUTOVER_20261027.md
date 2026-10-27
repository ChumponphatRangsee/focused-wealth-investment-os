# FWIOS Valuation v2 Production Cutover Receipt

Date: **2026-10-27 (Asia/Bangkok)**  
Status: **LIVE / PRODUCTION / ROLLBACK VERIFIED**  
Promotion policy: `POL-VALUATION-PROMOTION-V1`

## Scope

This cutover promotes the three validated period-aware v2 valuation routes that were previously shadow-only:

- ACN — `IT_SERVICES_FCF_COMPOUNDER_V1::2.0`
- EOG — `E&P_NORMALIZED_FCF_YIELD_V1::2.0`
- NFLX — `STREAMING_FCF_DCF_V1::2.0`

No trading, holdings, transactions, cash, approval, or accounting state is changed.

## Apply / rollback migration

Live migration:

`20261027020107 valuation_promotion_apply_rollback_v1`

It adds:

- `fwios.apply_valuation_promotion_v1(shadow_run_id)`
- `fwios.rollback_valuation_promotion_v1(production_run_id)`

Both are security-invoker, service-role-only functions.

Promotion behavior:

1. re-check `AUTO_ELIGIBLE`;
2. lock the shadow/model/current-production state;
3. re-check policy after locking;
4. create a new production run instead of mutating the shadow;
5. copy scenarios, canonical inputs and resolved lineage;
6. retire the previous production model version;
7. promote v2 and set `production_read_cutover=true`;
8. align `valuation_models` registry to v2 semantic metric identities;
9. verify Dashboard cutover;
10. retain the prior production run/version and registry snapshot for rollback.

Exact repeat apply calls return `NOOP_ALREADY_PROMOTED`.

## Pre-cutover dry-run

The complete three-model cutover was executed inside a transaction and rolled back before production mutation.

Result:

`VALUATION_V2_PRODUCTION_CUTOVER_DRY_RUN_PASS`

The dry-run verified all three Dashboard routes, singular production-version authority and total production-version count.

## Live production cutover

All three promotions were applied inside one transaction. Any single failure would have rolled back the entire batch.

### ACN

- production run: `VAL-PROD-ACN-ITSERV-V2-20261026`
- model version: `IT_SERVICES_FCF_COMPOUNDER_V1::2.0`
- Bear: 171.98535827
- Base: 232.65156828
- Bull: 325.56851356
- PW: **240.7142520975**
- rollback run: `VAL-SUPA-ACN-ITSERV-20260905`
- rollback version: `IT_SERVICES_FCF_COMPOUNDER_V1::1.0`
- production lineage: 10 edges

### EOG

- production run: `VAL-PROD-EOG-EP-V2-20261026`
- model version: `E&P_NORMALIZED_FCF_YIELD_V1::2.0`
- Bear: 43.5544038365
- Base: 170.2097882921
- Bull: 294.1920387901
- PW: **169.5415048027**
- rollback run: `VAL-EOG-20260904-P087`
- rollback version: `E&P_NORMALIZED_FCF_YIELD_V1@PHASE_0_87`
- production lineage: 8 edges

### NFLX

- production run: `VAL-PROD-NFLX-STREAM-V2-20261026`
- model version: `STREAMING_FCF_DCF_V1::2.0`
- Bear: 38.34206692
- Base: 73.14268190
- Bull: 121.18105874
- PW: **76.4521223650**
- rollback run: `VAL-NFLX-STREAM-20260911`
- rollback version: `STREAMING_FCF_DCF_V1::1.0`
- production lineage: 9 edges

Production Fair Values are exact copies of the approved shadow Fair Values; only live current-price upside is recalculated at cutover.

## Version authority

After cutover:

- all three v2 versions are `PRODUCTION`;
- all three prior versions are `RETIRED`;
- `production_read_cutover=true` on the v2 contracts;
- the global authoritative production-version count remains **20**;
- `valuation_models.model_version=2.0` for all three;
- model registry required metric identities now use generic period-aware semantics.

## Idempotency

Calling the apply function again for each original shadow returned:

`NOOP_ALREADY_PROMOTED`

No duplicate production run was created.

## Rollback verification

All three rollback functions were executed inside a transaction.

Within the test transaction:

- ACN Dashboard returned to `VAL-SUPA-ACN-ITSERV-20260905`;
- EOG returned to `VAL-EOG-20260904-P087`;
- NFLX returned to `VAL-NFLX-STREAM-20260911`;
- exactly one production version per model remained;
- total production-version count stayed at 20.

The transaction was then rolled back, leaving live production on v2.

Result:

`VALUATION_V2_ROLLBACK_DRY_RUN_PASS`

## Live regression

`FWIOS VALUATION V2 PRODUCTION CUTOVER: PASS (14/14, ROLLBACK-VERIFIED)`

The promotion-policy lifecycle test was also updated for post-cutover state:

`FWIOS VALUATION PROMOTION POLICY V1: PASS (12/12, POST-CUTOVER)`

## Readiness state

`v_research_readiness_current_v1` now resolves the new v2 production runs for ACN/EOG/NFLX and reports all three as `VALUATION_READY`.

They are **not** automatically investment-review-ready: current blockers are in Quality / Durability Hardening. Valuation promotion does not bypass downstream investment gates.

## Existing Google Sheet verification

The existing **Focused Wealth Dashboard - Chumponphat / Valuation Map** reflects the v2 values without a manual Sheet edit:

- ACN: FV 240.71, price 247.27
- EOG: FV 169.54, price 163.69
- NFLX: FV 76.45, price 63.90

This confirms the existing display path consumed the production cutover.

## Safety invariants

During the live cutover transaction, row counts for:

- `portfolio_transactions`
- `portfolio_source_positions`
- `portfolio_live_holdings_rows_v1`
- `human_approval_packets`

were captured before promotion and asserted unchanged after promotion.

The production runs also record:

- `human_execution_only=true`
- `auto_trade=false`

No order placement or portfolio/accounting mutation occurred.

## Simplified operating flow

For future valuation refreshes:

`Evidence → Canonical Metrics → Resolver → Shadow Valuation → Promotion Policy`

Then:

- `AUTO_ELIGIBLE` + explicit human authorization → one `apply_valuation_promotion_v1()` call;
- repeat apply → deterministic NOOP;
- rollback if needed → one `rollback_valuation_promotion_v1()` call;
- `MANUAL_REVIEW` or `BLOCKED` never cuts over.
