# Chase Risk v1

Policy version: `POL-CHASE-SCORE-V1`

## Purpose
Measure whether price has outrun the fundamental revision and conservative fair-value reference after the latest material earnings event.

## Components
Chase Risk = Price Extension 25% + Price vs Revision 30% + Multiple Expansion 25% + Price vs FV 20%. Lower is better. Chase Risk Max = 60.

All four components are mandatory; incomplete data => BLOCKED.

## Anchor
Anchor price = last regular-session close before the latest material earnings release. Current price = authoritative native market-price snapshot.

## Raw-to-risk mappings

### Price Extension
Raw = current/anchor - 1, in percent.
Risk = `clamp(max(raw,0) × 2.5, 0, 100)`.

### Price vs Revision
Raw = event price return (%) - comparable consensus revision (%).
Risk = `clamp(max(raw,0) × 2.5, 0, 100)`.

### Multiple Expansion
Pre multiple = pre-event price / pre-event FY EPS consensus.
Current multiple = current price / post-event FY EPS consensus.
Raw = current/pre multiple - 1, in percent.
Risk = `clamp(max(raw,0) × 2.5, 0, 100)`.

### Price vs Fair Value
Reference FV = `min(Base FV, probability-weighted FV)`.
Raw = current/reference FV - 1, in percent.
Piecewise risk breakpoints: -20%=0, -10%=15, 0%=40, +10%=65, +25%=100; linear interpolation between breakpoints.

## Gate
- Full component coverage required.
- Chase Risk <= 60 => PASS.
- Chase Risk > 60 => `FAIL - CHASE RISK`.
- Missing critical input => `BLOCKED - INCOMPLETE CHASE DATA`.

## Production parity
- PINS: Chase Risk 0.0000 — PASS.
- RDDT: Chase Risk 12.2748 — PASS.

RDDT still fails Promotion because its separate Mispricing Gate fails; Chase cannot override valuation.

Boundary and candidate regressions are stored under `REG-M2-POLICY-V1-*` in `fwios.decision_policy_regression_runs`.