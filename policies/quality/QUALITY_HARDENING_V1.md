# Quality / Durability Hardening v1

Policy: `POL-QUALITY-HARDENING-V1`  
Status: **ACTIVE**  
Execution: **HUMAN ONLY**

## Purpose
Prevent a candidate from becoming an Immediate Buy Candidate merely because a point-in-time DCF shows large upside, the stock has low chase risk, or it fits the portfolio well. The policy distinguishes verified mispricing from a possible value trap.

## Promotion gates
Every candidate must clear all four gates before Immediate promotion:
1. **Business Durability** — current growth cannot be extrapolated into a multi-year valuation without a verified durability anchor. Default minimum anchor is 3 years of comparable business/KPI evidence or an explicitly justified alternative.
2. **Owner Earnings** — reported FCF must be reconciled to dilution/stock-based compensation economics when SBC is material. SBC/revenue <=10% can clean-pass this narrow test; >10% requires explicit reconciliation; >20% is hard-review territory; >30% fails v1.
3. **Value Trap** — extreme modeled mispricing (>=75% base/PW trigger) requires a documented counter-thesis explaining why the market discount is likely wrong. Historical price weakness is only a review trigger, never an expected-return input.
4. **Valuation Robustness** — valuation must remain defensible under conservative assumptions and must not rely on an unverified multi-year growth extrapolation. Bear downside worse than 30% requires review; worse than 50% is a v1 fail threshold.

Missing critical hardening evidence fails closed to `BLOCKED`.

## Valuation confidence
Gate factors:
- PASS = 1.00
- REVIEW = 0.70
- BLOCKED = 0.40
- FAIL = 0.00

`valuation_confidence = mean(four gate factors)`

Expected Return v3:
`continuous_upside_score(u) = clamp(50 + 100*u, 0, 100)`

`expected_return_score = (60% × base-upside score + 40% × probability-weighted-upside score) × valuation_confidence`

The Focused Wealth core weights remain unchanged:
- Business / Thesis 30%
- Expected Return / Valuation 30%
- Portfolio Fit 25%
- Downside Risk 15%

## Ranking behavior
`POL-OPPORTUNITY-RANKING-V2`:
- Promotion PASS + Hardening PASS => `IMMEDIATE_BUY_CANDIDATE`
- Mispricing insufficient while other gates pass => `WATCHLIST_VALUE_WAIT`
- Mispricing PASS but Hardening not PASS => `WATCHLIST_MODEL_REVIEW`
- all other cases => `EXCLUDED`

Only `IMMEDIATE_BUY_CANDIDATE` is capital eligible. No force-fill.

## PINS validation case
Under the 2026-09-06 hardening review:
- Business Durability: BLOCKED
- Owner Earnings: BLOCKED
- Value Trap: BLOCKED
- Valuation Robustness: BLOCKED
- Valuation confidence: 0.40
- Expected Return score: 100 -> 40
- Core score: 87.6 -> 69.6
- Bucket: Immediate -> `WATCHLIST_MODEL_REVIEW`

The downgrade is not caused by the five-year stock chart. It is caused by insufficient verified durability, owner-economics, counter-thesis and valuation-robustness evidence.

## RDDT validation case
RDDT remains `WATCHLIST_VALUE_WAIT` because mispricing is insufficient. Its hardening evidence is also incomplete and must clear before any future Immediate promotion.

## Invariants
- no historical-return proxy for expected return;
- no AI-invented numeric scoring;
- no automatic trade or portfolio mutation;
- immutable historical Decision Snapshots remain audit history;
- new evidence requires a new hardening/score/decision snapshot;
- human broker execution remains separate.
