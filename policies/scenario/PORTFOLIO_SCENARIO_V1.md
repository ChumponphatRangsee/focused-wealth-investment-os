# Portfolio Scenario Simulation v1

Policy: `POL-PORTFOLIO-SCENARIO-V1`  
Domain: Capital Allocation  
Status: ACTIVE after 28/28 deterministic regressions  
Execution: HUMAN REVIEW ONLY / NO AUTO-TRADE

## Purpose
Deterministically simulate before/after portfolio state without mutating live holdings. M3.3 is a simulation layer, not a recommendation layer: it can evaluate hypothetical trims supplied as inputs, but it does not choose which asset to trim. Asset-selection/recommendation belongs to M3.4.

## Source authority
- Latest reconciled portfolio batch from Supabase.
- Active `POL-OPPORTUNITY-RANKING-V1`.
- Active `POL-NEW-CASH-ALLOCATION-V1`.
- Exact Decision Snapshot and Mispricing Snapshot for every simulated ADD.
- Current portfolio exposure for every simulated TRIM.

## Supported modes
### `NO_SELL`
- Requires positive new cash.
- No TRIM input allowed.
- Uses the same ranking and position-capacity logic as M3.2.
- Residual capital remains `CASH_THB`.

### `SOFT_REBALANCE`
- No TRIM input allowed in v1.
- For a one-time new-cash event, arithmetic is intentionally identical to `NO_SELL`.
- The semantic distinction is retained for future recurring DCA / capital-redirection state; the engine must not invent a fake numerical difference before that state exists.

### `ACTIVE_REBALANCE`
- May accept hypothetical TRIM inputs.
- Each trim must reference a currently held asset, be <= current position value, and carry an explicit rationale code.
- `PRICE_APPRECIATION_ONLY` / `APPRECIATION_ONLY` is forbidden.
- Trim proceeds plus new cash may be reallocated only through the active Immediate-candidate path.
- M3.3 does not decide that a trim should occur; it only simulates supplied inputs.

## Scenario outputs
- Actions: TRIM / ADD / HOLD.
- Position before value, delta, after value.
- Before/after portfolio weights.
- Max single-stock weight.
- Crypto weight.
- Open-position count.
- Residual cash.
- Added-asset valuation and downside lineage.
- Valuation coverage gate.
- Covered expected-upside contribution.
- Full portfolio probability-weighted upside only when valuation coverage is complete.
- Modeled expected-value change only when every changed non-cash asset has traceable valuation.

## Expected-upside fail-closed rule
At activation, current holdings valuation coverage is 0%. Therefore:
- `full_portfolio_pw_upside` is `BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE`.
- No cost-basis return, historical performance, narrative target, or unverified consensus may substitute for missing expected-return valuation.
- A covered ADD such as PINS can still expose its own exact probability-weighted/base upside and incremental expected-value contribution.
- An ACTIVE scenario that trims an uncovered holding (for example NVDA at activation) must block net expected-value comparison even if the ADD side is covered.

## Current reference lineage
PINS ADD path:
`OPPRANK-M3-20260905-01-PINS → DEC-PINS-M2-20260905-V2 → MIS-PINS-20260904`

Reference synthetic NO_SELL 50k:
- PINS ADD = THB 19,545.30
- CASH_THB HOLD = THB 30,454.70
- PINS post-money weight ≈ 5%
- Current max stock weight declines from ~41.25% to ~35.98% by denominator dilution.
- Current crypto weight declines from ~38.09% to ~33.22% by denominator dilution.
- Full portfolio expected upside remains blocked because existing holdings are not valuation-covered.

Reference synthetic ACTIVE input only:
- Hypothetical NVDA TRIM THB 10,000 + new cash 0 can be simulated and reallocates THB 10,000 to PINS under current capacity.
- Max stock concentration declines to ~38.32%.
- Net expected-value change is blocked because NVDA lacks current traceable valuation.
- This is a regression scenario, not a recommendation to trim NVDA.

## Invariants
1. Scenario previews never mutate live portfolio state.
2. Scenario previews never create orders or broker instructions.
3. NO_SELL / SOFT cannot contain TRIM.
4. ACTIVE trim amount cannot exceed current holding value.
5. Every ADD must trace to active Opportunity Ranking + Decision Snapshot.
6. RDDT Value-Wait cannot receive capital.
7. Residual cash is held; never force-fill.
8. Appreciation alone cannot justify trim.
9. Missing holding valuation blocks full expected portfolio upside.
10. Missing valuation on any changed asset blocks net modeled expected-value change.
11. `REBALANCE` remains DRAFT after M3.3.

## Regression suite
Prefix: `REG-M3-SCENARIO-V1-*`  
Activation result: **28/28 PASS**.

The suite covers mode separation, trim capacity, rationale guard, M3.2 parity, RDDT exclusion, Decision/Mispricing lineage, weight conservation, concentration/crypto effects, valuation fail-closed behavior, candidate downside lineage, ACTIVE trim arithmetic, non-mutation, and REBALANCE remaining DRAFT.
