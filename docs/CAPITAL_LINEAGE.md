# Capital Lineage & Rebalance Attribution v1.1

## Design principle: reuse existing tabs first

Capital Lineage is a Shadow Mode analytical layer. It answers one user question:

> Where did the money currently invested in this position come from?

It must not create a second portfolio UI or a second accounting system.

The user-facing model is intentionally limited to three existing tabs:

1. **Dashboard** — quick summary.
2. **Holdings** — funding mix for each position.
3. **Performance** — explicit external money entering or leaving the portfolio.

The only dedicated Capital Lineage sheets are two hidden engine tables:

- `_Capital Lots`
- `_Capital Allocations`

The temporary `Capital Events` and `Capital Dashboard` tabs were removed after UX review because they duplicated existing information and increased cognitive load.

## Authority boundaries

- `Transactions` remains the canonical transaction ledger.
- `Holdings` remains authoritative for quantity and Cost Basis.
- `Performance` is the external-capital-flow source; positive values mean contribution and negative values mean withdrawal.
- BUY/SELL activity must never be interpreted as external capital.
- Supabase/FWIOS remains the market-price infrastructure.
- Capital Lineage never feeds back into Cost Basis, P&L, or trading.

## What the user sees

### Dashboard

Two compact metrics were added to the existing summary:

- **Invested from New Money**
- **Invested from Profit**

These are current cost-basis attribution metrics, not portfolio value or realized-return metrics.

### Holdings

Two columns were added:

- **Capital Mix**
- **Profit From**

Examples:

- `Legacy / Unknown`
- `38% Profit · 62% Old/Unknown`
- `22% New · 33% Profit · 46% Old/Unknown`

`Profit From` identifies the asset whose realized gain generated the profit capital, such as NVDA.

The UI intentionally says **Old/Unknown** instead of the internal enum `LEGACY_UNKNOWN`.

### Performance

The existing contribution field is reused and renamed conceptually as **External Capital Flow THB**:

- positive = money added from outside the portfolio;
- negative = money withdrawn;
- zero = no external capital event.

No separate Capital Events sheet is required for the current MVP.

## Why two hidden engine tables remain

### _Capital Lots

Represents a source of capital or returned cash. Examples:

- Fresh Capital
- Realized Profit
- inherited/recycled principal
- older money whose historical source cannot be proven

### _Capital Allocations

Maps those capital lots to investments. It is separate from Lots because one BUY can be funded by multiple sources, and one capital lot can later fund multiple BUYs.

Keeping Lots and Allocations separate is the minimum useful structure for future mixed-origin partial SELL handling. They remain hidden because the user should not need to read them during normal use.

## Reference case

The current Shadow Mode migration proves the intended behavior for:

- NVDA → TLN on 2026-08-31
- NVDA → TTWO on 2026-09-03
- NVDA → TTWO on 2026-10-07
- Best external contribution of ฿10,000 on 2026-09-03 from `Performance!D18`

Current visible interpretation:

- TLN: approximately 38% profit-funded and 62% Old/Unknown.
- TTWO: approximately 22% New, 33% Profit, and 46% Old/Unknown.
- Profit origin for both traced profit-funded exposures: NVDA.

## Checks

Capital Lineage validation is reused inside the existing hidden `Checks` sheet under a separate **Capital Lineage Shadow Checks** block.

It verifies:

- TLN attribution reconciliation;
- TTWO attribution reconciliation;
- no negative lot balances;
- no duplicate allocation IDs;
- no cross-account/currency contamination;
- the verified 2026-09-03 Best external contribution remains ฿10,000.

These checks are deliberately independent from the core `Overall Operational Status`. A Shadow Mode attribution issue must not block portfolio valuation.

## Accounting behavior

### BUY

A BUY may consume multiple same-account, same-currency capital lots. Native-currency amounts must reconcile to the broker cash requirement. THB attribution is reporting metadata only.

### SELL with profit

The existing transaction ledger determines disposed Cost Basis and Realized P&L.

A profitable SELL produces:

1. returned capital preserving the origin mix of the disposed investment; and
2. a new Realized Profit lot whose origin asset is the asset sold.

### SELL with loss

Only actual proceeds return as capital. The lost portion is not recreated.

### Unknown history

Unknown history is a valid result. It must remain Old/Unknown until evidence exists. It must never be relabeled as New Money merely to make the model look complete.

## Automation gate

Future transaction-triggered lineage remains disabled.

Before enabling it:

1. implement deterministic lot consumption;
2. implement proportional mixed-origin partial SELL behavior;
3. consume explicit Performance external-capital events;
4. fail closed when source lineage is ambiguous;
5. verify native-currency and THB reconciliation;
6. prove no mutation of existing accounting or pricing.

`auto_trade=false` and `portfolio_mutation=false` remain unchanged.
