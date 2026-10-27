# FWIOS Clean-Room E2E Test #1 — MA (Mastercard)

**Date:** 2026-10-27 Asia/Bangkok  
**Git baseline:** `main@f3b96b3e6b869151c1bf388ff527f02373b2d471`  
**Live Supabase:** `ysjbmeukwbfnxnwqchuq`  
**Contract baseline:** `FWIOS-CONTRACT-0.87.26`  
**Execution mode:** human execution only; `auto_trade=false`

## Executive result

Clean-Room E2E Test #1 proved the ticker-only path from canonical identity through primary-source evidence, canonical reported metrics, explicit derived metrics, valuation routing/Fair Value, verified market price, mispricing, and canonical Quality Hardening without reusing legacy ticker-specific research/valuation state.

The run is **not a full end-to-end PASS**. It fails closed after Quality Hardening because Payment Network is not registered in the active Revision/Chase v2 contracts and because controlled research ingest intentionally does not create `research_candidates` / core research scores. Decision therefore blocks with `CORE_RESEARCH_SCORE_MISSING`; Opportunity Quality is not materialized.

A separate lineage audit also found that market-price and mispricing state is referenced by Hardening payloads but is not represented as first-class `lineage_artifacts` / `lineage_edges`. Evidence → metric → derived metric → valuation → hardening lineage is resolved; market → mispricing graph lineage remains a shared gap.

## Read-only baseline and isolation boundary

Before mutation, verified:

- GitHub `main` = `f3b96b3e6b869151c1bf388ff527f02373b2d471`.
- `docs/CURRENT_STATUS.md` and `contracts/system-contract.yaml` still require Portfolio Fit retired, Opportunity Ranking v2 retired, unchanged valuation / Quality Hardening / risk / Chase thresholds, and `auto_trade=false`.
- Live Supabase project is healthy.
- MA canonical instrument identity already existed: Mastercard Incorporated, Stock, Financials / Payment Network, NYSE, USD.
- Payment Network routes to implemented production model `PAYMENT_NETWORK_FCF_DCF_V1::1.0`.
- Pre-test MA ticker-specific derived-state counts were zero for `research_candidates`, `evidence_records`, `metric_observations`, `valuation_runs`, Quality Hardening snapshots, Decision snapshots, and Opportunity Quality snapshots.
- Historical stock data was not deleted.
- The only pre-existing MA layer intentionally admitted was canonical market data. The selected current daily close was already present in the shared market service.

This made **ticker/instrument identity** the smallest safe clean-room isolation boundary: all research/valuation/decision-derived MA state began empty while shared model/policy configuration and canonical market infrastructure remained reusable system services.

## Stage results

| Stage | Result | Evidence / output |
| --- | --- | --- |
| Ticker identity | PASS | MA resolved to instrument `9251df22-7173-41be-bec2-01499fdfade9`. |
| Evidence / data collection | PASS | 4 Tier-A SEC/company-primary evidence records; controlled-ingest preview 4/4 PASS. |
| Canonical reported metrics | PASS | 22/22 observations accepted; no blocker. |
| Explicit derived metrics | PASS | 6 derived observations with source-observation IDs and evidence lineage. |
| Validation / provenance | PASS | Required valuation inputs are fresh within route policy, Tier-A verified, provenance PASS, quality PASS. |
| Valuation model routing | PASS | Financials / Payment Network → `PAYMENT_NETWORK_FCF_DCF_V1::1.0`, kernel `FCF_COMPOUNDER`. |
| Fair Value | PASS | Bear 310.4742 / Base 475.3015 / Bull 710.9092 / probability-weighted 492.9966 USD/share. |
| Verified market price | PASS | 2026-10-26 close = 613.84 USD; `PRIMARY_ONLY`, price gate PASS, provenance PASS. |
| Mispricing | PASS computation / FAIL investment gate | PW upside = -19.6865%; `FAIL - INSUFFICIENT MISPRICING`. |
| Quality Hardening | PASS execution / REVIEW gate | Durability PASS; Owner Earnings PASS; Value Trap PASS; Robustness REVIEW; Overall REVIEW; confidence 0.925. |
| Revision | BLOCKED | Payment Network is not registered in active Revision v2; unregistered archetype policy is BLOCKED. No row synthesized. |
| Chase | BLOCKED | Payment Network has no active Chase v2 component contract; missing/full-coverage rules fail closed. No row synthesized. |
| Core scoring | BLOCKED | Controlled research ingest does not mutate `research_candidates`; no core research score exists for MA. |
| Decision | BLOCKED | `CORE_RESEARCH_SCORE_MISSING`; no Decision row. |
| Opportunity Quality | BLOCKED / not materialized | No `research_candidates` row; current v3 refresher is global rather than ticker-scoped. Global unrelated refresh was intentionally not run. |
| Lineage completeness | PARTIAL / BLOCKED for full E2E claim | Evidence/metrics/derivations/valuation/hardening graph resolved; market-price and mispricing are not first-class lineage artifacts/edges. |
| Overall Test #1 | BLOCKED after Quality Hardening | Fail-closed behavior is correct; full ticker-only E2E is not yet proven. |

## Evidence actually collected

All evidence was primary-source and persisted through the controlled research gateway:

| Evidence ID | Source | Purpose |
| --- | --- | --- |
| `AI-EV-FAF7E591B0341E2DF295DA5B` | Mastercard 2025 Form 10-K, SEC EDGAR | FY2023–FY2025 revenue and FY2025 cash-flow primitives. |
| `AI-EV-5B8838DEA3035F653A175648` | Mastercard Q2 2026 Form 10-Q, SEC EDGAR | Q2/H1 revenue, operating margin, SBC, cash-flow primitives, diluted weighted-average shares. |
| `AI-EV-79C6F72DF037F2EB17A721A3` | Mastercard Q2 2026 Form 10-Q balance sheet/liquidity | Unrestricted cash/investments and total debt. |
| `AI-EV-1F73D9F533BA2AAD06BD6269` | Mastercard Q2 2026 earnings exhibit filed with SEC | GDV, local-currency GDV growth, cross-border growth. |

Controlled APPLY receipt: `3bf4e828-1af5-4883-a5bb-b953eb314b2e`; 4 evidence rows + 22 reported metric observations inserted; `research_candidates_mutated=false`; `scanner_score_mutated=false`; portfolio mutation false.

## Canonical reported metrics

The 22 direct observations include:

- Revenue: FY2023 25.098B, FY2024 28.167B, FY2025 32.791B, H1 2026 17.675B, Q2 2026 9.277B USD.
- FY2025 cash flow: OCF 17.648B, property/equipment capex 0.489B, capitalized software 0.726B.
- H1 2025 comparative: OCF 6.983B, capex 0.199B, capitalized software 0.367B.
- H1 2026: OCF 6.772B, capex 0.445B, capitalized software 0.368B, SBC 0.326B.
- Q2 2026 payment-network drivers: GDV 2,900B USD, payments-volume growth 0.08, cross-border growth 0.12, operating margin 0.602.
- Q2 2026 diluted weighted-average shares: 883M.
- 2026-06-30 unrestricted cash/investments 11.6B and total debt 24.643B USD.

No derived number was inserted through the controlled ingest as `REPORTED_DIRECT`.

## Derived metrics and formulas

| Metric | Formula | Result |
| --- | --- | ---: |
| FY2025 FCF | OCF − capex − capitalized software | 16.433B USD |
| H1 2025 FCF | OCF − capex − capitalized software | 6.417B USD |
| H1 2026 FCF | OCF − capex − capitalized software | 5.959B USD |
| LTM FCF | FY2025 FCF − H1 2025 FCF + H1 2026 FCF | 15.975B USD |
| Net cash | unrestricted cash/investments − total debt | -13.043B USD |
| Take-rate proxy | Q2 revenue / Q2 GDV | 0.0031989655 |

Every derived observation is `observation_layer='DERIVED'`, provenance PASS, quality PASS, and records its exact source observation IDs.

## Valuation

Valuation run: `VAL-CR-MA-20260730-7be4d2f453d4`.

Inputs selected by the generic Payment Network runner:

- payments volume growth = 0.08
- cross-border growth = 0.12
- take-rate sanity = 0.0031989655
- operating margin sanity = 0.602
- LTM FCF = 15.975B
- net cash = -13.043B
- shares = 883M

Existing production assumptions and probabilities were used unchanged:

- Bear: growth 7% / 4%, discount 10%, terminal 3%.
- Base: growth 10% / 6%, discount 9%, terminal 3.5%.
- Bull: growth 12% / 8%, discount 8.25%, terminal 4%.
- Probabilities: 25% / 50% / 25%.

Market price is explicitly excluded from model assumptions and joins only downstream for mispricing.

## Market price and mispricing

Selected canonical market verification:

- verification `DCL:MA:2026-10-26`
- selected close 613.84 USD
- gate PASS
- verification status `PRIMARY_ONLY`
- conflict status `NO_CROSSCHECK`
- provenance PASS
- primary provider Twelve Data, Tier A

Compatibility snapshots created by Quality Hardening refresh:

- price: `PX-DCL-MA-20261026-59b8cd0336`
- mispricing: `MIS-QHR-MA-20261026-81f608b0fd`

Upside versus 613.84:

- Bear -49.4210%
- Base -22.5692%
- Bull +15.8134%
- probability-weighted -19.6865%

Mispricing gate = `FAIL - INSUFFICIENT MISPRICING`.

## Quality Hardening

Canonical snapshot: `HARD-QCE-MA-20261026-9daea2f632dc`.

- Business Durability: PASS — three annual revenue anchors.
- Owner Earnings: PASS — positive LTM FCF; H1 2026 SBC / revenue ≈ 1.8444%.
- Value Trap: PASS.
- Valuation Robustness: REVIEW.
- Overall: REVIEW.
- Valuation confidence: 0.925.

During Test #1 a generic authority bug was found: the base and canonical hardening snapshots shared the exact same `created_at`, and the current view could select the base BLOCKED row by lexical snapshot ID. Migration `20261027051904_quality_hardening_current_canonical_precedence_v1` fixes tie precedence so canonical evidence wins without changing any threshold.

## Lineage audit

Current MA lineage graph:

- 4 EVIDENCE artifacts
- 28 METRIC_OBSERVATION artifacts
- 1 VALUATION_RUN artifact
- 2 HARDENING_SNAPSHOT artifacts
- 65 resolved edges
- 0 unresolved edges

Edge counts:

- 30 `EVIDENCE_SUPPORTS_METRIC`
- 16 `METRIC_DERIVES_METRIC`
- 7 `METRIC_INPUT_TO_VALUATION`
- 4 `EVIDENCE_SUPPORTS_HARDENING`
- 6 `METRIC_SUPPORTS_HARDENING`
- 2 `VALUATION_SUPPORTS_HARDENING`

All seven valuation inputs have resolved metric→valuation edges.

**Known graph gap:** `market_verification_sets`, `market_price_snapshots`, and `valuation_mispricing_snapshots` are not valid artifact types in the current lineage graph constraint, so there is no first-class market→price→mispricing→hardening edge chain. Their IDs/provenance are present in operational rows/payloads, but this is insufficient for a full-lineage E2E PASS.

## Legacy reuse audit

No legacy MA research/derived state was reused:

- earliest MA evidence/metric creation: 2026-10-27 05:17:08Z
- valuation creation: 05:18:00Z
- mispricing/hardening creation: 05:18:12Z
- every normalized valuation input points to an observation created by this run and has provenance/quality PASS.

The only reused MA data was the **shared canonical market layer by design**. MA had historical canonical daily closes before Test #1; the current verified 2026-10-26 close was selected under the existing price policy. This is not reuse of legacy research/valuation/decision state.

## Idempotency

After the shared period-identity fix:

- exact controlled research APPLY replay → `NOOP_ALREADY_APPLIED`
- all six derivation APPLY replays → `NOOP_ALREADY_APPLIED`
- valuation APPLY replay → `NOOP_ALREADY_APPLIED`
- canonical Hardening APPLY replay → `NOOP_ALREADY_REFRESHED`
- repeat lineage sync added 0 edges

The replay exposed and fixed a generic bug: YTD and QUARTER metrics sharing the same `period_end` could be falsely treated as conflicting verified observations. Migration `20261027052154_research_ingest_period_type_conflict_identity_v1` adds `period_type` to the non-quarter/year conflict identity.

## Protected-state proof

Before Test #1:

- portfolio_transactions = 58
- portfolio_source_positions = 32
- portfolio_live_holdings_rows_v1 = 15
- portfolio_accounts = 3
- human_approval_packets = 1
- human_approval_events = 0

After Test #1:

- portfolio_transactions = 58
- portfolio_source_positions = 32
- portfolio_live_holdings_rows_v1 = 15
- portfolio_accounts = 3
- human_approval_packets = 1
- human_approval_events = 0

No holdings, cash, transactions, accounting, approvals, or execution state was changed. `auto_trade=false` throughout.

## Shared fixes completed during Test #1

1. Added a generic explicit derived-metric path with provenance and source-observation lineage.
2. Added a generic Payment Network valuation preview/apply runner using the existing production kernel and model registry.
3. Fixed canonical-vs-base Hardening current-view tie precedence.
4. Fixed controlled research ingest period-type conflict identity so exact replay is idempotent.

No fix contains an MA-only conditional, MA-only threshold, or relaxed valuation / Hardening / risk / Chase policy.

## Remaining shared gaps before a full E2E claim / Test #2

1. **Market/mispricing graph lineage:** add first-class artifact/edge support for verified market price and mispricing, then require resolved lineage before downstream lineage-sensitive acceptance.
2. **Ticker-only core scoring bridge:** controlled research intentionally does not create `research_candidates`; define a generic, provenance-backed way to create/refresh the core research score state without bypassing current scoring policy.
3. **Scoped Opportunity Quality refresh:** current v3 refresher is global over `research_candidates`; add or prove a ticker-scoped idempotent refresh before clean-room tests mutate downstream state.
4. **Revision/Chase archetype coverage:** Payment Network correctly blocks as unregistered. This is a coverage limitation, not a reason to weaken thresholds. Either register it through an explicit cross-sector policy design with acceptance evidence, or choose Test #2 from an already registered downstream archetype to test the remaining pipeline.

## Next recommended test

Do **not** patch MA to force a Decision. First close market/mispricing lineage and ticker-only scoring/scoped Opportunity orchestration. Then run Test #2 on a fresh ticker whose valuation model **and** Revision/Chase archetype are already supported, again with zero ticker-specific derived research state.

