# 02 — Scoring and Gates

Contract version: **FWIOS-CONTRACT-0.87.0**

## Production scoring core

The Focused Wealth-Building production score uses exactly:

| Component | Weight |
|---|---:|
| Business / Thesis Quality | 30% |
| Expected Return / Valuation | 30% |
| Portfolio Fit | 25% |
| Downside / Thesis Risk | 15% |
| **Total** | **100%** |

These weights are production core. Revision, catalyst, price-extension and timing signals are not allowed to replace or dominate them.

## Business / Thesis Quality

The quality layer is business-model aware. Current generic quality construction uses:

- Moat 20%
- Revenue Quality 15%
- Unit Economics 15%
- Balance Sheet 10%
- Growth 15%
- Capital Allocation 10%
- Sector KPI 15%

The archetype-specific KPI interpretation from `Sector_Criteria` overrides generic interpretation.

Current minimum investable quality gate: **70**.

## Expected Return / Valuation

Production expected-return score is based on **verified intrinsic valuation only**.

Current policy:

- 60% Base Fair Value upside score
- 40% Probability-Weighted Fair Value upside score

If verified intrinsic valuation is missing, Expected Return is **BLOCKED**.

Current mispricing thresholds:

- minimum Base FV upside for mispricing PASS: **15%**
- minimum Probability-Weighted upside for mispricing PASS: **10%**
- stronger starter-investigation thresholds: Base **20%**, PW **15%**
- Strong Buy investigation requires Base upside at least **25%** plus the remaining hard gates.

## Portfolio Fit

Portfolio Fit is not diversification for its own sake. It evaluates whether the next unit of capital improves the whole portfolio.

Mandatory questions:

- Does the candidate worsen an existing concentration?
- Is it highly correlated with current holdings/themes?
- Does it add an independent return driver?
- Is it superior to adding to an existing high-quality holding?
- Is waiting in cash better at current valuation?

Current Portfolio Fit hard-gate minimum: **50**.

Portfolio rules outside the score still apply:

- exceptional single-stock allocation ~30% max before explicit concentration review;
- crypto target ~15–20% during Phase 1;
- prefer 5–8 meaningful positions;
- use new cash for soft rebalancing where practical.

## Downside / Thesis Risk

Higher score means lower permanent-loss risk.

Current policy combines:

- Risk Gate
- balance-sheet strength
- structural risk penalty

The system is fail-closed. Missing critical risk evidence cannot silently become a favorable score.

## Timing modifier

Revision/catalyst/timing signals are non-core and capped at **±5** around the core opportunity score.

They may improve prioritization but cannot turn a failed hard gate into a promoted opportunity.

## Chase / FOMO gate

Current Chase Risk maximum: **60**.

The gate is explicitly fail-closed:

- if full Chase Risk is available, compare it with the max;
- if not, but known Price Extension Risk exceeds the max, FAIL;
- otherwise, missing components remain BLOCKED rather than defaulting to PASS.

This is designed to stop the system from chasing a stock merely because business quality and valuation look attractive.

## Promotion logic

A candidate cannot be promoted unless all required evidence and decision gates pass.

Conceptual hard-gate chain:

1. Production Evidence Gate PASS
2. Data Freshness Gate PASS
3. Schema Gate PASS
4. Risk Gate not failed
5. Quality Gate PASS
6. Valuation Gate PASS
7. Mispricing Gate PASS
8. Chase Gate PASS
9. Portfolio Gate PASS
10. Final score threshold reached

`READY FOR HUMAN REVIEW` is the furthest the automated system may go.

## Final-decision classes

Typical machine outcomes include:

- DATA BLOCKED
- REJECT - RISK
- REJECT - QUALITY
- WAIT FOR VALUATION
- WAIT - MISPRICING
- WAIT - CHASE RISK
- AVOID ADD - PORTFOLIO
- WATCHLIST ONLY
- RESEARCH PRIORITY
- STARTER BUY CANDIDATE
- STRONG BUY INVESTIGATION

An attractive standalone score does not override a failed portfolio or chase gate.

## Candidate limits

- Sector shortlist: maximum **5**, never force-fill.
- Global active candidates: maximum **5**.
- Immediate buy candidates: maximum **3**.

When many ideas qualify, rank them against each other and choose the best use of the next unit of capital.
