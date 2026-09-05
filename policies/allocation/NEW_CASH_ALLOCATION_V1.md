# New-Cash Capital Allocation v1

Policy: `POL-NEW-CASH-ALLOCATION-V1`  
Domain: `CAPITAL_ALLOCATION`  
State: **ACTIVE / DETERMINISTIC**  
Execution: **HUMAN REVIEW ONLY**

## Purpose
Deploy newly available THB capital without selling current holdings, while preserving the Focused Wealth-Building rules and the M3 traceability chain.

This policy is not a trade instruction and never mutates the live portfolio.

## Inputs
A production allocation preview requires:
- positive requested new cash;
- latest reconciled portfolio batch = PASS;
- latest production Opportunity Ranking run = PASS;
- Opportunity Ranking policy version = ACTIVE;
- ranking portfolio batch must equal the latest portfolio batch;
- production Decision Snapshot and referenced Portfolio Fit snapshot must remain traceable.

Any material mismatch fails closed.

## Eligible candidates
Only `IMMEDIATE_BUY_CANDIDATE` rows from active Opportunity Ranking v1 may receive capital.

`WATCHLIST_VALUE_WAIT`, `EXCLUDED`, stale, blocked or untraceable candidates receive zero capital.

v1 supports **Stock** candidates only. Unsupported asset classes have zero allocation capacity until a dedicated allocation policy exists.

## Focus rule
Opportunity Ranking may expose up to 3 Immediate candidates, but New-Cash Allocation v1 deploys capital to **at most 1 asset per run**.

The selected asset is the highest-ranked Immediate candidate with positive allocation capacity. Residual cash is held as `CASH_THB`; the engine never force-fills the second-ranked candidate.

## Position sizing
### New position
Maximum new starter position after the cash injection:

`5% × post-money portfolio value`

where post-money value includes all requested new cash, including any residual cash held.

### Existing position
Per-run staged-add capacity is the smaller of:
- 5% of post-money portfolio value; and
- remaining headroom to the 30% exceptional single-stock ceiling.

An existing stock already above 30% receives zero new-cash capacity.

These are allocation caps, not target allocations.

## Portfolio effects
The preview reports before/after:
- total portfolio value;
- allocated and unallocated new cash;
- max single-stock weight;
- crypto weight;
- unique open asset count;
- new-cash deployment ratio;
- residual new-cash weight.

Existing deviations remain visible as review flags. They do not trigger automatic selling.

## Current production parity
Using portfolio batch `PORTFOLIO-M2-20260905-01` and ranking run `OPPRANK-M3-20260905-01`:
- THB 10,000 preview → PINS THB 10,000; residual cash THB 0.
- THB 50,000 preview → PINS THB 19,545.30; residual cash THB 30,454.70.
- THB 100,000 preview → PINS THB 22,045.30; residual cash THB 77,954.70.
- RDDT receives THB 0 because it remains `WATCHLIST_VALUE_WAIT` from insufficient Mispricing.

These amounts are **synthetic regression previews**, not a recommendation to deploy those amounts.

## Guardrails
- New cash first.
- No sell/trim in M3.2.
- No force-fill.
- Max one deployed asset per run.
- New stock starter cap 5% post-money.
- Existing stock add cap 5pp per run and never above 30% post-money.
- Unsupported asset classes fail closed.
- Every ADD must trace to a ranking candidate and Decision Snapshot.
- Residual cash is valid.
- `REBALANCE` remains DRAFT.
- No auto-trading.

## Regression gate
Suite: `REG-M3-NEWCASH-V1-*`  
Status: **20/20 PASS**.

Coverage includes capacity boundaries, 30% ceiling, unsupported asset class, invalid/stale inputs, current production input parity, one-asset focus, Value-Wait exclusion, ADD traceability, 10k/50k/100k production parity, concentration and crypto direction, focus-review visibility, and non-mutation of allocation/portfolio state.
