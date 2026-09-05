# REBALANCE_V1

Status: ACTIVE after 12/12 deterministic regressions.
Policy ID: `POL-REBALANCE-V1`.
Execution: HUMAN REVIEW ONLY. No auto trade and no portfolio mutation.

## Production rules
1. New cash is consumed before any trim.
2. ADD candidate must be an active `IMMEDIATE_BUY_CANDIDATE` with exact Decision Snapshot valuation lineage.
3. A trim source must be a current holding with traceable fresh production valuation.
4. Source holding must require concentration review (>30% under Phase-1 policy) for v1 active trim logic.
5. Probability-weighted expected-return edge must be at least 25 percentage points.
6. Recommended trim = min(remaining approved candidate capacity after new cash, source concentration excess above 30%).
7. Do not trim more than can be redeployed into the approved opportunity.
8. 30% is a review threshold, not a forced target. A starter-sized reallocation may intentionally leave the holding above 30%.
9. Appreciation alone is never a valid trim rationale. Production rationale is `CONCENTRATION_AND_OPPORTUNITY_COST`.
10. Holdings without current valuation coverage are excluded, not proxied.
11. Full-portfolio expected-upside coverage may remain blocked while a changed-assets comparison is valid, provided every changed non-cash asset is covered.
12. Max one new position per cycle; no force-fill.

## Current parity examples — synthetic only
- New cash THB 0: NVDA trim ~17,045.30 → PINS add ~17,045.30; READY - HUMAN REVIEW.
- New cash THB 10,000: use THB 10,000 new cash first, then NVDA trim ~7,545.30 to fill PINS starter capacity.
- New cash THB 50,000: PINS starter capacity is fully funded by new cash; no NVDA trim.

These are regression previews, not trade instructions. Real recommendations require fresh broker price verification and human approval.