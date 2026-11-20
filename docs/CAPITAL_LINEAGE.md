# Capital Lineage & Rebalance Attribution v1

## Status

Capital Lineage v1 is implemented in the Investment Portfolio Tracker as a **Shadow Mode analytical layer**. It does not replace or feed back into the existing transaction accounting, Holdings quantity, Cost Basis, Realized P&L, Unrealized P&L, pricing, or trading paths.

Automation for future transactions is **not enabled**. The current implementation is an evidence-backed historical/reference migration plus dashboard and integrity controls.

## Authority boundaries

- `Transactions` remains the canonical transaction ledger.
- `Holdings` remains formula-derived and authoritative for quantity and Cost Basis.
- `Performance` remains authoritative for explicit contribution history.
- Supabase/FWIOS remains the market-price and downstream pricing infrastructure.
- Capital Lineage reads accounting facts and produces attribution only.
- `contracts/system-contract.yaml` remains the price-service contract and is intentionally not extended into portfolio accounting.

## Google Sheet surfaces

### Capital Events

External money entering or leaving the investment portfolio.

Columns:

`Capital Event ID, Date, Account, Event Type, Currency, Native Amount, THB Amount, Source, Evidence, Confidence, Notes, Status`

Initial event types:

- CONTRIBUTION
- WITHDRAWAL
- OPENING_CASH
- ADJUSTMENT

A historical BUY is never automatically treated as Fresh Capital.

### _Capital Lots

Hidden internal ledger of capital sources and returned cash.

Columns:

`Lot ID, Account, Created Date, Currency, Origin Class, Origin Asset, Origin Transaction, Parent Lot, Source Event ID, Conversion FX Rate, Native Amount Created, Native Amount Remaining, THB Attribution Amount, THB Attribution Remaining, Status, Confidence, Notes`

Origin classes:

- FRESH_CAPITAL
- REALIZED_PROFIT
- INCOME
- LEGACY_UNKNOWN

Returned principal is not a new origin class. It inherits the lineage of the capital that originally funded the sold asset.

### _Capital Allocations

Hidden many-to-many mapping between investments and capital lots.

Columns:

`Allocation ID, Investment Source ID, Source Type, Capital Lot ID, Account, Asset, Native Currency, Native Amount Allocated, Native Amount Remaining Invested, THB Attribution, THB Attribution Remaining, Allocation Date, Origin Class, Origin Asset, Confidence, Notes`

The two remaining-value columns allow later partial SELL logic to reduce an investment's attributable capital without rewriting the original allocation.

### Capital Dashboard

User-facing analytical surface containing:

- Fresh Capital contributed
- withdrawals
- Realized Profit generated
- Realized Profit reinvested
- current profit-funded exposure
- current fresh-capital-funded exposure
- available/unallocated cash
- Legacy/Unknown current exposure
- Portfolio Value
- Capital Multiplier when historical capital is sufficiently complete
- per-holding attribution
- reference-case decomposition
- integrity checks

If historical external capital is incomplete, Capital Multiplier intentionally reports N/A instead of implying a false precision.

## Accounting logic

### BUY

A BUY consumes same-account, same-currency Capital Lots. Native-currency allocation must reconcile to the actual cash required by the BUY. THB attribution is reporting metadata and must reconcile to the existing THB Cost Basis without replacing it.

### SELL with profit

The existing Transaction Ledger remains the source of Cost Basis disposed and Realized P&L.

A profitable SELL produces:

1. returned inherited capital that preserves the sold exposure's lineage; and
2. a new REALIZED_PROFIT lot whose Origin Asset is the sold asset.

### SELL with loss

Only the actual net proceeds can return as capital. No synthetic principal is created to replace the loss.

### Mixed origins

When a position contains multiple capital origins, a partial SELL must return the origins proportionally to the relevant disposed basis. Any new realized profit becomes a new REALIZED_PROFIT lot for the asset being sold.

## Native currency and THB attribution

Native Currency is the reconciliation unit for broker cash.

THB Attribution is the portfolio reporting unit.

For the current migrated exposure, THB attribution uses the investment-date FX rate. This is why a USD amount inherited from a SELL can have a different THB attribution when reinvested later without violating native-cash reconciliation.

## Confidence policy

- VERIFIED: direct contribution evidence or directly calculated ledger result.
- HIGH: strong same-account, same-currency SELL-to-BUY lineage.
- MEDIUM: likely relationship with incomplete evidence.
- UNKNOWN: origin cannot safely be reconstructed.

UNKNOWN is a valid result. Converting unknown historical money into Fresh Capital is not.

## Current Shadow Mode integrity controls

The Capital Dashboard verifies:

- existing Operational Checks remain OK;
- Holdings quantity and Cost Basis remain equal to the captured baseline;
- Realized P&L remains equal to the captured baseline;
- lot balances are not negative;
- allocation IDs are not duplicated;
- reference BUYs reconcile in native currency;
- current holding attribution reconciles to existing Cost Basis;
- account and currency boundaries are respected;
- unknown history is explicitly reported;
- the 3 Sep 2026 Best contribution remains ฿10,000.

## Automation gate

Automation is deliberately disabled. Before enabling transaction-triggered lineage:

1. define a deterministic available-lot consumption policy;
2. implement mixed-origin partial-SELL reduction using remaining invested amounts;
3. handle contributions/withdrawals as explicit cash events;
4. add fail-closed behavior for ambiguous origin;
5. test new BUY/SELL sequences against native-currency reconciliation;
6. verify no change to existing accounting formulas or FWIOS pricing;
7. re-run all integrity checks.

`auto_trade=false` and `portfolio_mutation=false` remain unchanged.
