# Opportunity Ranking v1

Policy version: `POL-OPPORTUNITY-RANKING-V1`

## Purpose
Rank production Decision Snapshots for the next capital-allocation step without creating a second weighted investment score or bypassing any M2 hard gate.

## Source boundary
Only the latest production Decision Snapshot per ticker may enter the ranking layer. Every ranked candidate must preserve the exact `decision_snapshot_id`, `score_snapshot_id`, and `portfolio_batch_id` lineage.

## Priority score
`priority_score = core_score`

The 30/30/25/15 core score already embeds Business / Thesis, Expected Return / Valuation, Portfolio Fit, and Downside / Thesis Risk. Opportunity Ranking must not re-weight those components again.

Tie-break order when priority scores are equal:
1. Expected Return score DESC
2. Portfolio Fit score DESC
3. Downside Risk score DESC
4. Business / Thesis score DESC
5. Ticker ASC

## Buckets

### IMMEDIATE_BUY_CANDIDATE
Requirements:
- `input_integrity_gate = PASS`
- `promotion_gate = PASS`

Maximum surfaced candidates: **3**.

This bucket means eligible for downstream capital-allocation simulation. It is not a trade instruction and still requires current price/portfolio verification before any real investment recommendation.

### WATCHLIST_VALUE_WAIT
Requirements:
- `input_integrity_gate = PASS`
- `mispricing_gate = FAIL - INSUFFICIENT MISPRICING`
- Quality, Valuation, Portfolio Fit, Downside, Revision, Chase and Core Scoring gates all PASS

Maximum surfaced candidates: **5**.

This isolates companies that otherwise pass the decision system but are not attractive enough on current valuation.

### EXCLUDED
All other states remain auditable but are not surfaced as current opportunities. Missing/stale/blocked critical inputs, non-mispricing hard-gate failures and candidates above bucket caps remain EXCLUDED.

## Information-overload controls
- Immediate buy candidates: max 3
- Active value watchlist: max 5
- Do not force-fill either bucket
- Actual new purchase per decision cycle is normally 0-1 after M3.2 allocation review

## Fail-closed invariants
1. Promotion FAIL/BLOCKED cannot enter Immediate.
2. A non-mispricing hard-gate failure cannot be converted into a value watchlist candidate.
3. Missing input integrity => EXCLUDED.
4. Ranking cannot modify M2 scores or gates.
5. Ranking cannot mutate portfolio holdings or transactions.
6. Human execution only.

## Production activation
Regression suite: **8/8 PASS**.

Production parity:
- PINS / `DEC-PINS-M2-20260905-V2` → `IMMEDIATE_BUY_CANDIDATE`, rank 1, priority 87.6000.
- RDDT / `DEC-RDDT-M2-20260905-V2` → `WATCHLIST_VALUE_WAIT`, rank 1, priority 72.1500.

First production ranking run:
- `OPPRANK-M3-20260905-01`
- portfolio batch `PORTFOLIO-M2-20260905-01`
- status `PASS`

M3.1 ranking output is an input to M3.2 Capital Allocation only; it is not an allocation or rebalancing recommendation.