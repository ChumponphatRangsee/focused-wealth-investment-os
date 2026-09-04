# 03 — Valuation Contracts

Contract version: **FWIOS-CONTRACT-0.87.0**

`Sector_Criteria` is the canonical registry for business-model-specific valuation contracts.

A configured contract does **not** imply an implemented production model. Unimplemented contracts must remain fail-closed.

## Configured valuation model registry

| Archetype | Model ID | Required Metric IDs |
|---|---|---|
| Upstream E&P | `E&P_NORMALIZED_FCF_YIELD_V1` | `fcf_fy2025; fcf_5y_median; fcf_ltm; total_production_mboed; oil_production_mbod; cash_operating_cost_per_boe; net_debt; shares_outstanding` |
| Refining / Oilfield Services | `OFS_MIDCYCLE_EV_EBITDA_FCF_V1` | `orders_qtr; rpo; fcf_ltm; adjusted_ebitda_ltm; net_debt; shares_outstanding` |
| SaaS / Application Software | `SAAS_EV_FCF_REVERSE_DCF_V1` | `arr_growth_yoy; nrr; gross_margin; fcf_margin_ltm; revenue_ltm; fcf_ltm; sbc_to_revenue; net_cash; shares_outstanding` |
| Digital Advertising Platform | `DIGITAL_ADS_FCF_REVERSE_DCF_V1` | `revenue_ltm; ad_revenue_growth_yoy; engagement_growth; operating_margin; fcf_ltm; capex_ltm; net_cash; shares_outstanding` |
| Large Pharma | `PHARMA_RNPV_PE_V1` | `revenue_ltm; fcf_ltm; top_drug_revenue_pct; patent_expiry_year; phase3_program_count; net_debt; shares_outstanding` |
| Medical Devices / Surgical Robotics | `MEDTECH_INSTALLED_BASE_DCF_V1` | `procedure_growth_yoy; installed_base; installed_base_growth_yoy; recurring_revenue_pct; revenue_ltm; fcf_ltm; fcf_margin_ltm; cash_and_investments; interest_bearing_debt; shares_outstanding` |
| Managed Care / Providers | `MANAGED_CARE_NORMALIZED_PE_V1` | `adjusted_eps_guidance; medical_cost_ratio; membership; reserve_development; revenue_ltm; fcf_ltm; net_debt; shares_outstanding` |
| Life Science Tools | `LIFE_SCI_TOOLS_FCF_V1` | `organic_growth_yoy; recurring_revenue_pct; book_to_bill; operating_margin; fcf_ltm; net_debt; shares_outstanding` |
| Payment Network | `PAYMENT_NETWORK_FCF_DCF_V1` | `payments_volume_growth; cross_border_growth; take_rate; operating_margin; fcf_ltm; net_cash; shares_outstanding` |
| Midstream | `MIDSTREAM_EV_EBITDA_DCF_YIELD_V1` | `adjusted_ebitda_ltm; dcf_ltm; distribution_coverage; net_debt; shares_outstanding` |
| Data Center REIT | `DATA_CENTER_REIT_AFFO_NAV_V1` | `affo_per_share; occupancy; bookings; rent_spread; net_debt_to_ebitda; shares_outstanding` |
| Waste / Environmental Services | `WASTE_FCF_EV_EBITDA_V1` | `revenue_ltm; core_price_growth; volume_growth; adjusted_ebitda_ltm; fcf_ltm; net_debt; shares_outstanding` |
| Semiconductor Designer | `SEMIS_MIDCYCLE_DCF_V1` | `revenue_ltm; gross_margin; inventory_days; customer_concentration; fcf_ltm; net_cash; shares_outstanding` |
| Semiconductor Equipment / Foundry | `SEMICAP_MIDCYCLE_FCF_V1` | `bookings; backlog; service_revenue_pct; utilization; fcf_ltm; net_debt; shares_outstanding` |
| Restaurant / Hotel / Leisure | `RESTAURANT_UNIT_ECONOMICS_DCF_V1` | `same_store_sales_growth; traffic_growth; unit_count; unit_growth; restaurant_margin; revenue_ltm; fcf_ltm; net_cash; shares_outstanding` |
| Branded Goods / Specialty Retail | `BRANDED_RETAIL_FCF_YIELD_V1` | `underlying_sales_growth; gross_margin; inventory_growth; revenue_ltm; fcf_ltm; net_debt; shares_outstanding` |
| Merchant Power / Nuclear / Renewables | `MERCHANT_POWER_NORMALIZED_NAV_V1` | `generation_mwh; capacity_factor; hedged_generation_pct; adjusted_ebitda_ltm; fcf_ltm; net_debt; shares_outstanding` |

All currently configured contracts require Tier A evidence and use a 120-day contract-level maximum metric age in the current registry, subject to stricter freshness rules after a new filing/earnings event.

## Production implementations live in Phase 0.87

The live `System_Foundation` currently identifies five implemented production routes:

- `MEDTECH_INSTALLED_BASE_DCF_V1`
- `E&P_NORMALIZED_FCF_YIELD_V1`
- `RESTAURANT_UNIT_ECONOMICS_DCF_V1`
- `BRANDED_RETAIL_FCF_YIELD_V1`
- `OFS_MIDCYCLE_EV_EBITDA_FCF_V1`

All other configured contracts remain subject to the fail-closed rule until explicitly implemented and regression-tested.

## Model-boundary rules

### Evidence layer
May contain reported or deterministically derived facts only.

### Normalization layer
May standardize definitions, units and economic/cycle inputs with explicit methods and lineage.

### Valuation layer
Owns assumptions such as:

- forecast growth;
- margin trajectory;
- maintenance/growth reinvestment assumptions;
- target FCF yields / multiples;
- discount rates;
- terminal values;
- probability weights.

No assumption should be backfilled into `Evidence_Ledger` or `Company_Metrics_v2` as if it were a reported fact.

## Archetype-specific cautions

- **E&P:** never use peak commodity prices or a simple historical FCF average as true economic mid-cycle FCF without a current asset-base bridge.
- **OFS:** post-acquisition valuations must bridge post-close debt and acquired economics; do not mix pre-close balance-sheet facts with post-close enterprise value.
- **Restaurant:** price-only same-store sales cannot substitute for traffic/unit economics; growth capex and store maturation must be treated explicitly.
- **Branded Retail:** company-reported underlying/pro-forma growth must not be mislabeled as comparable sales when definitions differ.
- **Semiconductors:** peak-cycle extrapolation is prohibited.
- **Pharma/Biotech:** probability assumptions and rNPV belong in valuation, never raw evidence.
- **Merchant Power:** narrative scarcity alone cannot substitute for normalized power-price / contracted-cash-flow economics.

## Reference regressions in Phase 0.87

The live foundation currently maintains explicit regression coverage around ISRG, EOG, BKR, CAVA and TPR.

These regressions are guardrails, not immutable price targets. If model economics are deliberately changed, the documentation and expected regression outputs must be updated together.
