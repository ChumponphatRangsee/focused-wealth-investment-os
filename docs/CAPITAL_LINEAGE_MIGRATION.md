# Capital Lineage v1 — Historical Migration Receipt

Date: 2026-11-20  
Mode: Shadow Mode  
Production automation: disabled

## Preflight

Before adding Capital Lineage surfaces:

- the live Investment Portfolio Tracker was read;
- a Drive backup/reference copy was created;
- Transactions, Holdings, Performance, Dashboard and Operational Checks were baselined;
- current GitHub `main`, `docs/CURRENT_STATUS.md`, `contracts/system-contract.yaml`, and `docs/PRICE_PIPELINE.md` were re-read;
- the Dime screenshot transaction-ingestion workflow remained authoritative for transaction entry.

No existing accounting formula or historical transaction was changed.

## Baseline preserved

Post-migration verification found:

- Holdings quantity baseline: unchanged;
- Holdings Cost Basis baseline: unchanged;
- Realized P&L baseline: unchanged;
- Dashboard accounting metrics: unchanged;
- Performance contribution history: unchanged;
- existing Operational Checks: OK;
- failed existing Operational Checks: 0.

## Historical policy

The migration does not attempt to invent complete portfolio funding history.

Current holdings without sufficient external-cash evidence are seeded as `LEGACY_UNKNOWN` opening exposure. This makes current Cost Basis attributable without falsely declaring those historical investments to be Fresh Capital.

Closed or returned historical cash whose downstream use cannot be proven is quarantined rather than reported as available cash.

## Verified contribution — 3 Sep 2026

`Performance` records a Best-account Net Contribution of **฿10,000** on 2026-09-03.

This is recorded as:

- Source: `Performance!D18` / `PERF-20260903-BEST`
- External Capital Flow: +฿10,000
- Confidence: VERIFIED
- Fresh lot: `LOT-FRESH-BEST-USD-20260903`
- conversion attribution: 33.00 THB/USD

The fresh lot is allocated only where the cash-chain evidence supports it.

## Reference case — NVDA to TLN

### 31 Aug 2026

NVDA SELL `SRC-0026`:

- net native proceeds: approximately USD 599.96982
- Cost Basis disposed: ฿12,354.95
- Realized P&L: ฿7,612.05

TLN BUY `SRC-0027` requires approximately USD 599.99999.

Capital Lineage attributes TLN Cost Basis of **฿19,962.36** as:

- recycled inherited NVDA principal: **฿12,293.72**
- NVDA realized-profit capital: **฿7,667.63**
- other historical/unknown top-up: **฿1.00**

The USD 0.03017 top-up is deliberately UNKNOWN rather than invented as Fresh Capital.

## Reference case — NVDA to TTWO

### 3 Sep 2026

NVDA SELL `SRC-0028`:

- net native proceeds: approximately USD 605.95154
- Cost Basis disposed: ฿12,012.47
- Realized P&L: ฿7,983.93

TTWO BUY `SRC-0029` requires approximately USD 908.95937.

The residual requirement is approximately USD 303.00782. At the transaction FX of 33.00, this matches the explicit ฿10,000 contribution within the small residual/rounding difference and supports the Fresh Capital link.

### 7 Oct 2026

NVDA SELL `SRC-0030`:

- net native proceeds: USD 481.30
- Cost Basis disposed: ฿9,051.65
- Realized P&L: ฿7,132.79

TTWO BUY `SRC-0031` requires approximately USD 486.99999.

The migration consumes the small remaining USD balance of the verified 3 Sep Fresh Capital lot and leaves the remaining approximately USD 5.67751 as LEGACY_UNKNOWN because its source cannot be safely proven.

### Current TTWO attribution

Current TTWO Cost Basis: **฿46,371.76**

Attributed as:

- Fresh Capital: **฿10,000.01**
- recycled inherited NVDA principal: **฿20,958.86**
- NVDA realized-profit capital: **฿15,221.97**
- other Legacy/Unknown: **฿190.91**

The small difference between the original ฿10,000 contribution and current THB Fresh Capital attribution is expected: the capital is reconciled in USD, while the later reinvestment uses a different THB/USD attribution rate.

## Other realized profit

Historical CRWD realized-profit lots are created from the existing Transaction Ledger, but returned cash is marked `QUARANTINED_UNRESOLVED` because the downstream funding chain cannot be reconstructed safely. These lots are not counted as Available Cash.

## Current dashboard summary at migration

- Total verified Fresh Capital contributed: ฿10,000.00
- Realized Profit generated: ฿28,926.83
- Realized Profit reinvested into currently attributed TLN/TTWO exposure: ฿22,889.61
- current Profit-funded exposure: ฿22,889.61
- current Fresh-capital-funded exposure: approximately ฿10,000.01
- Available/Unallocated Cash: no verified available lot
- Legacy/Unknown current exposure: approximately ฿309,771.24
- Capital Multiplier: N/A because historical external capital is incomplete

## Acceptance checks

The Shadow Mode reference migration passes:

- no baseline Holdings quantity changes;
- no baseline Cost Basis changes;
- no Realized P&L changes;
- no negative lot balances;
- no duplicate allocation IDs;
- same-account/same-currency reference allocation;
- native BUY cash reconciliation for SRC-0027, SRC-0029 and SRC-0031;
- current holding attribution reconciliation;
- NVDA to TLN traceability;
- NVDA to TTWO traceability;
- explicit UNKNOWN history instead of fabricated Fresh Capital;
- existing Operational Checks remain OK.

## Remaining gate before Production automation

This receipt does **not** declare automatic Capital Lineage processing Production-ready. Future-transaction automation and mixed-origin partial-SELL mutation logic remain to be implemented and tested fail-closed.


## Same-day UX simplification — reuse-first architecture

After the reference migration passed, the user-facing design was reviewed for cognitive load.

The original temporary `Capital Events` and `Capital Dashboard` sheets were removed because they duplicated existing information.

Current presentation:

- `Dashboard` shows only two additional summary metrics: **Invested from New Money** and **Invested from Profit**.
- `Holdings` shows **Capital Mix** and **Profit From** per position.
- `Performance` is reused as the explicit external-capital-flow history.
- `_Capital Lots` and `_Capital Allocations` remain hidden as the minimum internal lineage engine.
- lineage integrity checks are placed in the existing hidden `Checks` sheet and remain independent from core portfolio valuation status.

The verified Best contribution is now referenced directly as `PERF-20260903-BEST` / `Performance!D18`.

This simplification made no change to transaction accounting, Holdings quantity, Cost Basis, Realized/Unrealized P&L, market prices, FWIOS runtime, or trading.
