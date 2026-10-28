# ACN Research State Resolver — Read-Only Pilot v1

**Verified:** 2026-10-28; Supabase project `ysjbmeukwbfnxnwqchuq`; pilot ticker **ACN only**.  
**Delivery:** SQL SELECT + regression SELECTs in a review branch. No production database DDL/DML, schedules, research APPLY, policy changes, Google Sheet writes or trading.

## Why this exists

Read live Supabase **before** spending SEC API calls or proposing new research. Distinguish model-required valuation input completeness from optional **annual canonical enrichment**. An SEC raw fact is not a verified, ingested canonical metric. A valuation can be available without the stock being investment-actionable.

## Files and execution

1. `sql/research/acn_research_state_resolver_readonly_v1.sql` — run the standalone single SELECT against Supabase (read-only SQL editor / connector). It returns exactly one ACN row with issuer/filing identity, SEC shadow fingerprint and observation time, current production valuation run, required input lineage, per-metric FY2026 annual canonical-vs-raw evidence state and a **proposed** research action.
2. `tests/research/test_acn_research_state_resolver_readonly_v1.sql` — standalone SELECT; all 12 checks must be `PASS`.

It uses existing `fwios.instrument_symbols`, `fwios.v_thesis_sec_filing_current`, `fwios.v_research_readiness_current_v1`, `fwios.valuation_runs`, `fwios.valuation_run_inputs`, `fwios.metric_observations`, `fwios.evidence_records`, `fwios.decision_refresh_shadow_evidence`. No new DB view or table required. Crucially, it queries **all period-specific metric observations**, not the collapsed `v_metric_observations_current` view.

### Source identity rules

- ACN SEC CIK: **0001467373**; most recently *stored/checked* 10-K accession `0001467373-26-000049`, filed **2026-10-16**, report period **2026-08-31**. Source checks observed **2026-10-28 06:10 UTC**.
- Annual shadow XBRL: requires **10-K**, exact **accession**, USD unit, **period_start 2025-09-01** and **period_end 2026-08-31**. Never use the SEC `fy` attribute alone to select a financial period: older comparative frames can carry `fy=2026` in a 2026 filing.
- Required valuation inputs: exact `valuation_run_inputs.source_key = metric_observations.observation_key`, numeric value equality, canonical unit, proper fiscal year/period type, metric `PASS` quality/provenance, and source evidence `VERIFIED` with `NO_CONFLICT`.
- Shadow evidence must have `collection_status=PASS`. A shadow XBRL fact being stored is **not** permission to promote it to canonical.

## Live results — 2026-10-28

| Item | Result |
|---|---|
| Valuation | `VAL-PROD-ACN-ITSERV-V2-20261026` |
| Model | `IT_SERVICES_FCF_COMPOUNDER_V1::2.0`, production-eligible |
| Required input lineage | **7/7 VERIFIED** |
| Probability-weighted Fair Value | **USD 240.7142520975/share** |
| Canonical FY2026 YEAR enrichment metrics present | **0/4** |
| FY2026 annual facts already stored in SEC Company Facts shadow | **4/4** |
| Missing SEC source facts for those four metrics | **0/4** |
| Proposed research action | `PREVIEW_CANONICAL_ENRICHMENT_FROM_STORED_SEC` |
| Quality Hardening | `REVIEW`; blocking reason `QUALITY_HARDENING_FAIL` |
| Test results | **12/12 PASS** |

Four stored *raw* primary-source figures, **not yet promoted to FY2026 canonical YEAR observations**:

| Target canonical metric | Matching SEC XBRL tag | Raw USD | Unit normalized for future PREVIEW only |
|---|---|---:|---:|
| `REVENUE` | `Revenues` | 74,183,445,000 | 74.183445 USD B |
| `OPERATING_CASH_FLOW` | `NetCashProvidedByUsedInOperatingActivities` | 12,363,346,000 | 12.363346 USD B |
| `CAPEX_PROPERTY_EQUIPMENT` | `PaymentsToAcquirePropertyPlantAndEquipment` | 742,748,000 | 0.742748 USD B |
| `SHARE_BASED_COMPENSATION` | `ShareBasedCompensation` | 2,100,433,000 | 2.100433 USD B |

Cross-check: FY2026 **12.363346 − 0.742748 = 11.620598 USD B** FCF; this matches the already ingested `FREE_CASH_FLOW` LTM observation for period 2025-09-01–2026-08-31. The previous `REVENUE` LTM as of **2026-05-31** does **not** count as FY2026 annual Revenue.

## Resolver action semantics

- `VALUATION_INPUTS_READY`: current selected production valuation uses all required verifiable source observations; does **not** mean Quality/Decision/Risk/Chase PASS.
- `STORED_SEC_FACT_NEEDS_PREVIEW`: matching raw SEC XBRL is **already in Supabase**, but typed canonical FY2026 YEAR observation is absent. Suggest targeted deterministic validation and existing `fwios.preview_research_ingest_v1` only after mapping/period/unit/source review.
- `SOURCE_FACT_MISSING_REVIEW`: matching source fact not found in latest checked shadow; check source coverage and provenance before deciding to call an API. This is **not** proof SEC has no such fact.
- `REVIEW_NEW_OR_MISSING_FILING`: stored most-recent selected form/report period does not match ACN FY2026 annual pilot. No automatic revaluation.
- `REVIEW_VALUATION_INPUT_LINEAGE`: fail closed if required input count, source value, period or verification mismatches.
- `NOOP_NO_ANNUAL_METRIC_GAPS`: optional annual metrics are present; **not** a claim that new filings elsewhere do not exist or that investment gates pass.

**No automatic APPLY.** Output explicitly contains `apply_authorized=false` and `auto_trade=false`.

## Boundaries / follow-up

- This is a **period-locked ACN FY2026 diagnostic SELECT**, not a generalized latest-filing detector or unattended scheduler. External SEC currentness is not guaranteed by stored `sec_checked_at`. Build separate, reviewed filing-delta behavior later using accession, form, period, amendment identity, XBRL context and fingerprints.
- The SEC shadow is a collector snapshot; source validation, units, accounting treatment, potential supersession/restatements and conflict checks remain required before controlled ingest. This SELECT does **not** call `preview_research_ingest_v1` or `apply_research_ingest_v1`.
- The model input checker deliberately fails closed on new unknown required keys outside these seven ACN input patterns. Do not repurpose for ADBE or PINS without a separately tested model-specific contract.
- No mutation to 64-stock market EOD collector, other 28 valued stocks, legacy data, Quality Hardening thresholds, Decision, Opportunity or portfolio/accounting objects. Cron job #10 defect remains a separately tracked operational issue.
- PR #92 (MA Clean Room) and #93 (Phase 1 docs scope lock) are open and independent of this implementation. **Do not merge automatically**.

## Next reviewed step

Prepare a **targeted ACN-only controlled ingest PREVIEW payload** from the four stored SEC XBRL facts with FY2026 duration/units/source evidence and explicitly confirm model metric definitions; no new SEC fetch if the existing verified stored source is sufficient. Do not APPLY without separate authorization. Re-check source currency, evidence accession, accepted dates, data model coverage and possible SEC amendments.
