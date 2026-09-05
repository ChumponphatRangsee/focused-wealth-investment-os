# Revision Score v1

Policy version: `POL-REVISION-SCORE-V1`

## Purpose
Measure whether fundamentals improved or deteriorated around the latest material earnings event. Absolute growth alone does not earn a high revision score.

## Formula
Revision Score = Guidance 30% + Consensus 25% + KPI Acceleration 25% + Margin/FCF 20%.

All four components are mandatory for Promotion. Missing, stale, conflicting, non-comparable or unverified critical data => BLOCKED.

For each component delta, use:
`score = clamp(50 + 5 × delta, 0, 100)`

Neutral = 50; -10 = 0; +10 = 100.

### Guidance
Raw delta = forward management revenue-guidance midpoint surprise (%) versus pre-guidance analyst consensus for the same forward period.

### Consensus
Raw delta = same-provider, same-metric, same-fiscal-period consensus revision (%).

### KPI Acceleration
Raw delta = average percentage-point change versus the immediately prior quarter in configured monetization/growth and engagement YoY growth rates using comparable definitions. Digital Advertising v1 uses monetization/ad-revenue growth and engagement growth.

### Margin / FCF
Raw delta = average of same-quarter YoY adjusted EBITDA-margin delta (pp) and same-quarter YoY FCF-margin delta (pp).

## Gate
- Full component coverage + provenance/freshness PASS required.
- Revision Score >= 50 => PASS.
- Revision Score < 50 => `FAIL - NEGATIVE FUNDAMENTAL REVISION`.
- Incomplete critical input => BLOCKED.

Revision is non-core and cannot override core, valuation, mispricing or Portfolio Fit gates.

## Production parity
- PINS Q2 2026: 60.5531 — PASS.
- RDDT Q2 2026: 71.4010 — PASS.

Boundary and candidate regressions are stored under `REG-M2-POLICY-V1-*` in `fwios.decision_policy_regression_runs`.