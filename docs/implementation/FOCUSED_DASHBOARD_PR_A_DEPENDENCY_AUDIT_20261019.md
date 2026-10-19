# Focused Wealth Dashboard PR-A Dependency Audit — 2026-10-19

## Scope

Read-only audit of the live Focused Wealth Dashboard, repository main, system contract, and live Supabase before UI cleanup.

## Live Sheet Dependency Map

| Sheet | Current source | Classification | Target |
| --- | --- | --- | --- |
| Dashboard | _Data portfolio/accounting blocks | REMOVE UI | Retire after scanner cutover |
| Valuation Map | _Data valuation block + GOOGLEFINANCE fallback | KEEP / REBUILD | _Scanner_Data |
| Thesis Tracker | _Data thesis block | BACKEND ONLY | Hide/remove tab after scanner validation |
| Opportunity Quality | _Data opportunity-quality block | BACKEND ONLY | Hide/remove tab after scanner validation |
| _Data | dashboard-refresh-csv-v1 monolithic payload | DEPRECATED AFTER CUTOVER | Keep during transition |
| _Scanner_Data | new scanner-refresh-csv-v1 feed | SCANNER ONLY | Hidden helper |

No current Sheet formula outside Valuation Map references Valuation Map. All four user-facing legacy tabs depend directly on _Data.

## Current Supabase Feed Coupling

dashboard_refresh_payload_v1 currently combines portfolio and research domains:
- v_dashboard_account_summary
- v_dashboard_holdings
- v_dashboard_opportunities
- v_opportunity_quality_current
- v_dashboard_valuation_map
- v_thesis_tracking_current
- v_dashboard_current_action
- v_dashboard_alerts
- v_dashboard_system_health

The refresh gate is also tied to portfolio-batch reconciliation. This is why a separate scanner read model is required rather than merely hiding portfolio cells.

## Object Classification

### SHARED
- canonical instrument identity
- market daily close / market price infrastructure
- provider quota / cache / refresh infrastructure

### PORTFOLIO_ONLY
- v_dashboard_account_summary
- v_dashboard_holdings
- v_dashboard_alerts
- v_dashboard_current_action
- portfolio transaction / holding / reconciliation / MTM / scenario objects
- portfolio-sheet-shadow-sync-v1

### SCANNER / RESEARCH BACKEND
- research_candidates
- valuation models/runs/scenarios
- thesis registry/events/health/memory
- opportunity_quality_score_v2
- v_thesis_tracking_current
- v_valuation_mispricing_current

### MIXED / COMPATIBILITY
- v_dashboard_valuation_map: valuation fields are reusable; decision/system signal columns are not scanner authority
- v_opportunity_quality_current: opportunity score is portfolio-independent, but scenario/final-buy fields are portfolio-aware

### DEPRECATED AFTER CUTOVER
- dashboard_refresh_payload_v1 as the Focused Sheet read model
- dashboard-refresh-csv-v1 as the Focused Sheet feed
- _Data helper tab

Do not drop any of the above during PR-A/PR-B.

## Scanner Coverage Reality

The current canonical market universe contains 64 ACTIVE Stock instruments plus 6 Crypto instruments. It is not a full ~500 constituent S&P 500 universe yet.

Current stock daily-close coverage is 64/64, with session dates spanning 2026-10-15 through 2026-10-16 at audit time.

The scanner UI must therefore state current coverage rather than imply that all S&P 500 constituents are already ingested.

## Scanner Score

The existing portfolio-independent discovery formula is retained:
- 35% Business Thesis
- 40% continuous expected-return/upside score
- 25% resilience = average of Quality and Downside Risk

Portfolio Fit, current holdings, portfolio scenario, position sizing, approval state and execution state are excluded from the scanner read model.

Unlike the stale opportunity snapshots in the legacy _Data feed, v_scanner_current_v1 recomputes expected return from the canonical latest daily close and current probability-weighted fair value.

## Valuation Classification

Scanner-only classification:
- STRONG UNDERVALUED: price <= Bear FV
- UNDERVALUED: Bear FV < price <= Base FV
- FAIR VALUE: Base FV < price <= probability-weighted FV
- EXPENSIVE: probability-weighted FV < price <= High FV
- VERY EXPENSIVE: price > High FV
- NO VALUATION: no current valuation

This classification is independent of current portfolio holdings.

## Safety

No transaction, cost basis, realized P&L, cash, holdings quantity, portfolio accounting formula, auto-trade flag, or portfolio-mutation path is changed by this PR.


## Live Implementation Result

Implemented and validated on 2026-10-19:

- `fwios.v_scanner_current_v1` is live as an additive, portfolio-independent read model.
- `scanner-refresh-csv-v1` is ACTIVE v2.
- `_Scanner_Data` is a hidden Sheet helper fed from the scanner endpoint.
- `S&P500 Scanner` is the first visible Sheet tab.
- `Valuation Map` was rebuilt from `_Scanner_Data`; GOOGLEFINANCE and portfolio/decision columns are no longer part of the user-facing valuation surface.
- Legacy `Dashboard`, `Thesis Tracker`, `Opportunity Quality`, and `_Data` are hidden, not deleted.
- Visible tabs are now only `S&P500 Scanner` and `Valuation Map`.

Validation snapshot:
- 64 active stock rows
- 27 scored rows
- 7 rows classified STRONG UNDERVALUED / UNDERVALUED
- market-session range 2026-10-15 through 2026-10-16
- no rank outside the valid scored range
- no #REF / #N/A / #VALUE errors in Scanner, Valuation Map, or _Scanner_Data verification ranges
- live system health still reports `auto_trade=false` and `human_execution_only=true`

## Residual Transition Dependency

`_Scanner_Data` intentionally derives the existing Sheet import credential URL from `_Data!V1` and swaps only the endpoint/revision. This avoided creating or exposing a second credential during the cutover.

Therefore:
- keep `_Data` hidden for now;
- do not delete `dashboard-refresh-csv-v1` or its access record yet;
- a later cleanup should decouple the scanner credential/config first, verify the scanner feed again, then remove the legacy Sheet tabs/read model if desired.

## Recommended Next Tasks

1. Decouple scanner Sheet import configuration from legacy `_Data!V1`, then retire the legacy Focused Dashboard feed/tabs after verification.
2. Update `AGENTS.md` and `contracts/system-contract.yaml` dashboard-read-model documentation to the new visible-tab/read-model contract.
3. Expand canonical stock-universe ingestion from the current 64 active stocks toward true S&P 500 constituent coverage; do not label current coverage as complete until that ingestion exists.
