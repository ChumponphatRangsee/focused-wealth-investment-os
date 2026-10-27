# FWIOS Quality Hardening Canonical Evidence v1 — Production Receipt

Date: 2026-10-27  
Contract target: `FWIOS-CONTRACT-0.87.23`  
Live migration: `20261027031421 quality_hardening_canonical_evidence_v1`

## Objective

Close the proven Quality Hardening evidence gap for EOG and NFLX without changing valuation architecture or weakening `POL-QUALITY-HARDENING-V1`.

The production path remains:

```
Primary Source
  → Controlled Research PREVIEW/APPLY
  → evidence_records
  → metric_observations
  → canonical hardening evidence resolver
  → Quality Hardening refresh
  → Research Readiness
```

Shadow collection evidence is discovery/supporting context only and never directly creates a production gate.

## Controlled canonical research ingestion

### EOG

Controlled receipt: `45a398e2-ac66-4ea9-a204-79747787ae40`  
Payload fingerprint: `d3016d1a1bf7bb9314aa16e89c1814d4`

Inserted:
- 1 Tier-A verified evidence record
- 2 canonical observations

Canonical observations:
- H1 2026 Revenue: **USD 15.541B**
- H1 2026 Share-Based Compensation: **USD 0.118B**

Primary source:
- SEC EOG Resources Q2 2026 Form 10-Q: `https://www.sec.gov/Archives/edgar/data/821189/000082118926000149/eog-20260630.htm`

Existing verified LTM Free Cash Flow remains **USD 6.653B**.

Resolved SBC / Revenue: approximately **0.7593%**, below the unchanged 10% clean-pass threshold.

### NFLX

Controlled receipt: `92d634fe-4281-44a4-8177-9d9c0364c8be`  
Payload fingerprint: `84e051bbce0d69fc222b606f540238cd`

Inserted:
- 2 Tier-A verified evidence records
- 5 canonical observations

Canonical annual revenue durability anchor:
- FY2023 Revenue: **USD 33.723297B**
- FY2024 Revenue: **USD 39.000966B**
- FY2025 Revenue: **USD 45.183036B**

Primary annual source:
- SEC Netflix 2025 Form 10-K: `https://www.sec.gov/Archives/edgar/data/1065280/000106528026000034/nflx-20251231.htm`

Canonical current owner-economics observations:
- 9M 2026 Revenue: **USD 37.683871B**
- 9M 2026 Share-Based Compensation: **USD 0.405440B**

Primary current source:
- SEC Company Facts: `https://data.sec.gov/api/xbrl/companyfacts/CIK0001065280.json`

Existing verified Q3 2026 Free Cash Flow remains **USD 2.883513B**.

Resolved SBC / Revenue: approximately **1.0759%**, below the unchanged 10% clean-pass threshold.

## Deterministic resolver

New service-role-only read function:

- `fwios.preview_quality_hardening_canonical_evidence_v1(ticker)`

Business Durability:
- consumes only canonical annual `REVENUE`;
- requires Tier-A verified, conflict-free, PASS provenance;
- requires at least the active hardening policy minimum consecutive annual years;
- latest annual anchor must be current or prior calendar year;
- does not invent an alternative durability anchor.

Owner Earnings:
- requires same-period canonical `REVENUE` + `SHARE_BASED_COMPENSATION`;
- requires Tier-A verified, conflict-free, PASS provenance;
- requires fresh positive verified `FREE_CASH_FLOW` for clean-pass owner economics;
- inherits existing SBC thresholds exactly:
  - <=10% clean narrow PASS;
  - >10% requires reconciliation;
  - >20% hard review;
  - >30% fail.

## Refresh overlay

New controlled functions:

- `fwios.preview_quality_hardening_canonical_refresh_v1(ticker)`
- `fwios.apply_quality_hardening_canonical_refresh_v1(ticker, human_authorized)`

The overlay preserves the proven base price/mispricing bridge and only replaces evidence-sensitive Durability/Owner Earnings gates when canonical evidence deterministically resolves them.

Value Trap and Valuation Robustness remain price/valuation-sensitive base hardening gates.

Apply:
- requires explicit human authorization;
- service-role-only;
- writes immutable hardening snapshots;
- writes normalized evidence/metric → hardening lineage;
- is idempotent.

A pre-release fingerprint defect was detected during live validation: the first prototype included the prior hardening snapshot ID in the deterministic fingerprint. That would have made repeat refreshes unstable. The production implementation was corrected to fingerprint effective gates/evidence instead. Final repeat calls return `NOOP_ALREADY_REFRESHED`.

## Production result

### EOG

Final current snapshot:
`HARD-QCE-EOG-20261026-8094977faaad`

- Business Durability: **PASS**
- Owner Earnings: **PASS**
- Value Trap: **PASS**
- Valuation Robustness: **FAIL**
- Overall: **FAIL**
- Valuation confidence: **0.7500**

EOG therefore remains fail-closed. The previous Owner Earnings evidence blocker is resolved, but the Bear-case robustness failure remains real.

### NFLX

Final current snapshot:
`HARD-QCE-NFLX-20261026-2d4df8695276`

- Business Durability: **PASS**
- Owner Earnings: **PASS**
- Value Trap: **PASS**
- Valuation Robustness: **REVIEW**
- Overall: **REVIEW**
- Valuation confidence: **0.9250**

NFLX improves from BLOCKED to REVIEW, but does not become PASS or investment-review-ready.

## Readiness

Both current hardening snapshots reference their current v2 production valuation runs.

- EOG: `quality_hardened=false`, `investment_review_ready=false`
- NFLX: `quality_hardened=false`, `investment_review_ready=false`

No buy/trade signal was created.

## Lineage

New hardening snapshots include explicit normalized lineage:

- `VALUATION_SUPPORTS_HARDENING`
- `EVIDENCE_SUPPORTS_HARDENING`
  - `DURABILITY_REVENUE`
  - `OWNER_EARNINGS_REVENUE`
  - `OWNER_EARNINGS_SBC`
  - `OWNER_EARNINGS_FCF`
- `METRIC_SUPPORTS_HARDENING`
  - same corresponding roles

NFLX carries three annual Revenue metric edges for the FY2023–FY2025 durability anchor.

## Regression

Canonical evidence acceptance: **16/16 PASS live SQL**.

Base Quality Hardening Refresh regression after the change: **10/10 PASS live SQL**.

Do not label either result as GitHub CI.

## Safety

Protected-state row counts before and after remained:

- `portfolio_transactions`: 58
- `portfolio_source_positions`: 32
- `portfolio_live_holdings_rows_v1`: 15
- `portfolio_accounts`: 3
- `human_approval_packets`: 1
- `human_approval_events`: 0

Policy flags:
- `portfolio_mutation=false`
- `approval_mutation=false`
- `execution_mutation=false`
- `auto_trade=false`
- `human_execution_only=true`
- `shadow_evidence_direct_promotion=false`

Post-DDL Supabase advisor inspection found no new security/performance advisory specifically tied to these canonical-hardening functions/policy.

## Next action

Do not retune EOG/NFLX hardening simply to obtain PASS.

The next MVP-1 step should move downstream from Hardening into **Decision / Ranking lineage refresh**, while preserving the current outcomes:
- EOG remains excluded/fail-closed because robustness FAIL.
- NFLX remains review-only because robustness REVIEW and current mispricing is insufficient.
- Separately reconcile the known stale PINS ranking regression fixture/current ranking drift.
