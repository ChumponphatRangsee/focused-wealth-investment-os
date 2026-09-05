# SEMIS_MIDCYCLE_DCF_V1

Status: PRODUCTION
Version: 1.0
Kernel: FCF_COMPOUNDER

Purpose: provide traceable current valuation coverage for Semiconductor Designer holdings before M3.4 rebalancing can compare expected returns.

## Required normalized inputs
- revenue_ltm
- gross_margin
- inventory_days
- customer_concentration
- fcf_ltm
- net_cash
- shares_outstanding
- pending committed acquisition consideration when a signed material transaction exists

## Method
Five-year equity FCF DCF followed by terminal value. Gross margin, inventory days and customer concentration are explicit diagnostics; they are not hidden score modifiers.

Scenario assumptions:
- Bear growth: 15%, 12%, 10%, 8%, 6%; discount 11.5%; terminal 3.0%.
- Base growth: 30%, 25%, 20%, 15%, 10%; discount 10.0%; terminal 3.5%.
- Bull growth: 40%, 32%, 25%, 20%, 15%; discount 9.0%; terminal 4.0%.
- Probabilities: 25% / 50% / 25%.

Signed pending acquisition purchase consideration is deducted from the conservative equity bridge. Employee retention consideration is not treated as purchase price unless explicitly classified as such by the source.

## NVDA production parity — 2026-09-05
Inputs: FCF LTM $127.006B; conservative net cash $23.220B; pending Hugging Face purchase consideration $11.9B; shares 24.1B; Q2 FY27 gross margin 75%; inventory days 150.2023; largest direct customer 16%.

Fair values:
- Bear $87.03032203
- Base $166.16708908
- Bull $273.20947981
- Probability weighted $173.14349500

Price snapshot: `PX-NVDA-20260904`, $230.34 regular close. Model regression `REG-SEMIS-V1-NVDA-PARITY` = PASS.

This valuation is an input to opportunity-cost analysis, not a standalone trim instruction.