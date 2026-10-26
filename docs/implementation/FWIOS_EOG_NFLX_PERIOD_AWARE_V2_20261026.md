# FWIOS EOG + NFLX Period-Aware v2

Date: **2026-10-26 (Asia/Bangkok)**  
Live migration: **20261026114938 — eog_nflx_period_aware_v2**  
Status: **LIVE semantic/contracts + shadow validation / no production cutover**

## Scope

This work extends the period-aware valuation pattern proven on ACN to the two remaining period-RED routes identified by the valuation audit:

- EOG — `E&P_NORMALIZED_FCF_YIELD_V1`
- NFLX — `STREAMING_FCF_DCF_V1`

Production model versions and the user-facing Valuation Map remain unchanged.

## EOG v2

New experimental version:

`E&P_NORMALIZED_FCF_YIELD_V1::2.0`

Key changes:

- legacy `fcf_fy2025` is replaced by semantic `FREE_CASH_FLOW + YEAR + LATEST_COMPLETED_FISCAL_YEAR`;
- LTM FCF resolves as `FREE_CASH_FLOW + LTM`;
- production, unit cost and net debt select the latest reported quarter;
- shares use latest filing economic shares outstanding;
- no fiscal year or quarter is encoded in metric identity;
- existing scenario normalization methodology and target FCF-yield assumptions are unchanged;
- `production_read_cutover=false`.

As of 2026-10-26, Q2 2026 is still the latest published EOG primary financial period. The canonical resolver returns **8/8 required PASS**.

Shadow run:

`VAL-SHADOW-EOG-EP-V2-20261026`

This is intentionally a semantic-parity run. It reuses the immutable scenario-normalization snapshot from production run `VAL-EOG-20260904-P087` and only tests the v2 input contract/lineage.

| Scenario | Production v1 | Shadow v2 |
|---|---:|---:|
| Bear | 43.55440384 | 43.55440384 |
| Base | 170.20978830 | 170.20978829 |
| Bull | 294.19203880 | 294.19203879 |
| Probability-weighted | 169.54150480 | 169.54150480 |

Differences are rounding-only. No methodology change is implied.

## NFLX v2

New experimental version:

`STREAMING_FCF_DCF_V1::2.0`

A new semantic metric was added:

`DILUTED_SHARES`

This separates a diluted weighted-average per-share denominator from period-end economic `SHARES_OUTSTANDING`. The legacy NFLX row is preserved for backward compatibility; v2 does not reuse its incorrect semantic label.

Required v2 selectors:

- current-FY `FREE_CASH_FLOW_GUIDANCE`;
- latest-quarter `NET_DEBT`;
- latest-quarter `DILUTED_SHARES`;
- latest-quarter `REVENUE_GROWTH_YOY`;
- latest-quarter `OPERATING_MARGIN`;
- current-FY guidance `CONTENT_CASH_TO_AMORTIZATION`.

Optional diagnostics:

- `ENGAGEMENT_GROWTH`;
- latest quarterly `FREE_CASH_FLOW`;
- `PENDING_ACQUISITION_CONSIDERATION`.

Before Q3 ingest, the resolver correctly returned **0/6 required PASS**, failing closed on stale Q2 data and missing diluted-share/current-guidance semantics.

## NFLX Q3 controlled research APPLY

Primary source:

- SEC-filed Netflix Q3 2026 shareholder letter, Exhibit 99.1, accession `0001065280-26-000290`.

Canonical current-period payload:

| Metric | Value |
|---|---:|
| FY2026 FCF guidance | 12.0 USD B |
| Q3 net debt | 7.113850 USD B |
| Q3 diluted shares | 4,195.127 M |
| Q3 revenue growth YoY | 11.8% |
| Q3 operating margin | 34.6% |
| FY2026 content cash/amortization | 1.1x |
| Q3 free cash flow | 2.883513 USD B |

Controlled PREVIEW: **7/7 metrics PASS, 1/1 Tier-A evidence PASS, 0 blockers**.

Controlled APPLY:

- fingerprint: `1660dc6c3ba9a084e26194f41d89f48d`
- receipt: `d442ba44-c090-4d14-aec7-c7bc38c31c75`
- evidence inserted: 1
- observations inserted: 7
- portfolio mutation: false
- scanner-score mutation: false
- research-candidate mutation: false
- auto trade: false
- human execution only: true

Repeating the exact receipt payload returned `NOOP_ALREADY_APPLIED`.

After APPLY, NFLX v2 resolver returns **6/6 required PASS**, with all 9 required+optional selectors passing.

## NFLX shadow valuation

Shadow run:

`VAL-SHADOW-NFLX-STREAM-V2-20261026`

The DCF kernel and long-duration scenario assumptions are unchanged from production v1. Only the current canonical inputs are refreshed.

| Scenario | Production v1 | Shadow v2 | Change |
|---|---:|---:|---:|
| Bear | 39.83055321 | 38.34206692 | -3.74% |
| Base | 75.52077644 | 73.14268190 | -3.15% |
| Bull | 124.78715849 | 121.18105874 | -2.89% |
| Probability-weighted | 78.91481615 | 76.45212237 | **-3.12%** |

At dashboard price 65.87, shadow probability-weighted upside is approximately **+16.07%**. This is a valuation comparison, not a trading recommendation.

## Lineage and production boundary

- EOG shadow input lineage: **8 resolved metric-input edges**
- NFLX shadow input lineage: **9 resolved metric-input edges**
- EOG shadow `production_eligible=false`
- NFLX shadow `production_eligible=false`
- EOG dashboard still reads `VAL-EOG-20260904-P087`
- NFLX dashboard still reads `VAL-NFLX-STREAM-20260911`
- no production model promotion
- no dashboard cutover
- no trading or portfolio/accounting mutation.

## Verification

Migration dry-run:

`EOG_NFLX_PERIOD_AWARE_V2_DRY_RUN_PASS`

Shadow transaction dry-run:

`EOG_NFLX_V2_SHADOW_DRY_RUN_PASS`

Live regression after APPLY/shadow creation:

`FWIOS EOG + NFLX PERIOD-AWARE V2: PASS (10/10, SHADOW/NON-PRODUCTION)`

## Next decision

ACN, EOG and NFLX now all have period-aware experimental contracts and validated non-production shadow runs.

The next step should be a cross-model promotion review, not an automatic cutover:

1. compare v1/v2 methodology and lineage per model;
2. define promotion acceptance criteria common to all three routes;
3. confirm rollback behavior;
4. promote each model separately only with explicit production authorization;
5. preserve human-execution-only and no-auto-trade controls.
