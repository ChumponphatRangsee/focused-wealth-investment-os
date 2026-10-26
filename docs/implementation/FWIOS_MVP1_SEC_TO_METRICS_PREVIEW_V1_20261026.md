# FWIOS MVP-1 — SEC SHADOW to Metrics PREVIEW v1

Date: **2026-10-26 (Asia/Bangkok)**  
Status: **PREVIEW-only pilot implemented and live-tested; no production APPLY**  
Pilot: **ACN FY2026 Form 10-K**  
Accession: **0001467373-26-000049**

## Scope

This slice closes the smallest missing link between the already-running SEC SHADOW collector and the existing controlled research-ingest validator:

```text
existing SEC schedule
  -> SEC_SUBMISSIONS / SEC_COMPANY_FACTS SHADOW
  -> deterministic ACN 10-K selection
  -> minimal normalized metrics
  -> fwios.preview_research_ingest_v1(...)
  -> PASS / BLOCKED result
```

It does **not**:

- call `fwios.apply_research_ingest_v1`;
- insert or update `evidence_records` or `metric_observations`;
- create or alter database schema;
- create or alter cron jobs;
- modify `decision-refresh-worker-v1`;
- recalculate or write a production valuation;
- change the Valuation Map;
- authorize trading.

`auto_trade=false` remains unchanged.

## Live read-only verification

Before implementation the live project was rechecked:

- the existing SEC SHADOW enqueue and worker cron jobs are active;
- ACN has fresh `SEC_SUBMISSIONS` and `SEC_COMPANY_FACTS` SHADOW rows;
- latest ACN 10-K is accession `0001467373-26-000049`, filed 2026-10-16 for the year ended 2026-08-31;
- `fwios.research_ingest_receipts_v1` remains empty;
- the current worker still stops at SHADOW and does not normalize, PREVIEW, APPLY, or revalue.

The latest compact ACN Company Facts SHADOW contains:

- Revenues;
- Net income;
- Operating cash flow;
- Capex;
- Cash and cash equivalents;
- Share-based compensation;
- diluted weighted-average shares;
- diluted EPS.

It does not currently contain enough information to reconstruct all current ACN valuation inputs safely.

## ACN FY2026 normalized pilot metrics

The query selects facts by **exact accession + form + period start + period end**.

This is intentional. ACN's 10-K contains a fiscal-Q4-like revenue row whose SEC metadata still has `fp=FY` and calendar frame `CY2026Q3`. Therefore the mapper must not infer fiscal-quarter semantics from `fp` or `frame` alone.

The PREVIEW payload currently contains only two unambiguous metrics:

| Metric | Value | Period | Derivation |
| --- | ---: | --- | --- |
| REVENUE | 74.183445 USD B | LTM / FY2026 ended 2026-08-31 | direct SEC XBRL fact |
| FREE_CASH_FLOW | 11.620598 USD B | LTM / FY2026 ended 2026-08-31 | OCF 12.363346B - capex 0.742748B |

The exact 10-K filing is used as Tier-A `REPORTED_FINANCIALS` primary evidence.

## Controlled PREVIEW result

Live PREVIEW returned:

- overall status: `PASS`;
- evidence count: 1;
- metric count: 2;
- blocker count: 0;
- warning count: 0;
- production changes: `NONE`.

Repeated PREVIEW of the same payload returned the same:

- payload fingerprint;
- revenue observation key;
- FCF observation key.

Counts in these production tables were unchanged before/after PREVIEW:

- `fwios.research_ingest_receipts_v1`;
- `fwios.evidence_records`;
- `fwios.metric_observations`.

## Why Fair Value is intentionally not recalculated yet

The current ACN production valuation uses `IT_SERVICES_FCF_COMPOUNDER_V1::1.0`.

Its required input contract still includes FY2026-guidance and Q3-specific fields such as:

- `fcf_guidance_low/midpoint/high`;
- `fy2026_revenue_growth_guidance_lc_mid`;
- `book_to_bill_q3`;
- `operating_margin_q3`;
- `gross_margin_q3`;
- `net_cash`;
- `shares_outstanding`.

After FY2026 closed, silently replacing those period-specific inputs with FY2026 actuals or FY2027 data would change model semantics without a model-version change.

The pilot therefore returns:

`BLOCKED_MODEL_PERIOD_ROLLOVER_REQUIRED`

with explicit blockers:

1. model v1 is still tied to FY2026 guidance and Q3-specific inputs;
2. current compact Company Facts SHADOW does not contain debt facts needed for a safe `NET_CASH` calculation;
3. diluted weighted-average shares are not equivalent to period-end shares outstanding;
4. FY2027 company guidance and bookings are not present in the current compact Company Facts SHADOW.

This is a deliberate fail-closed result, not a pipeline failure.

## Files

- `queries/mvp1_acn_sec_shadow_to_metrics_preview_v1.sql`
  - read-only ACN pilot mapper + controlled PREVIEW;
  - exposes source blockers and model revaluation blockers.
- `tests/research/test_mvp1_sec_to_metrics_preview_v1.sql`
  - 12 non-mutating regression checks.

## Regression coverage

The live regression checks cover:

1. current ACN Company Facts SHADOW exists;
2. target FY2026 10-K resolves to the expected primary document;
3. exact annual revenue row is unique;
4. fiscal-Q4 ambiguity is explicitly demonstrated (`fp=FY`, `frame=CY2026Q3`);
5. normalized revenue and FCF arithmetic match expected FY2026 values;
6. controlled PREVIEW passes and reports no production changes;
7. repeated PREVIEW is deterministic;
8. unverified evidence fails closed;
9. supported ACN valuation model resolves;
10. model period-rollover condition remains detectable;
11. an unsupported model does not silently become supported;
12. PREVIEW does not mutate controlled research tables.

Live result: **12/12 PASS**.

## Minimal next implementation sequence

### Step 1 — accept the PREVIEW-only bridge

Review this pilot and its blockers. No production state changes are required.

### Step 2 — close ACN's missing primary-source inputs

Before any production metric APPLY or valuation rerun, define the smallest source-backed set for the next model period:

- period-end shares outstanding;
- debt / net-cash bridge;
- FY2027 FCF guidance;
- FY2027 revenue-growth guidance;
- latest bookings / book-to-bill;
- current margin diagnostic inputs required by the next model contract.

Company-specific/non-GAAP fields that are not available in SEC Company Facts must use explicit primary issuer/filing evidence. They must not be inferred from unrelated XBRL tags.

### Step 3 — version the ACN valuation input contract

Do not reuse Q3/FY2026-specific metric codes as if they were current-period generic metrics.

Either:

- create a new model version whose input contract explicitly uses FY2026 actuals + FY2027 guidance; or
- first introduce/approve generic period-aware metric semantics and migrate the model contract.

This is a model/version decision, not a collector change.

### Step 4 — production APPLY only after separate owner authorization

Only after the complete payload passes PREVIEW and the model-period contract is accepted:

1. run the exact reviewed payload in controlled APPLY mode;
2. verify evidence/metric receipts and idempotency;
3. create a new immutable valuation run;
4. compare the resulting `v_dashboard_valuation_map` row with the existing Valuation Map;
5. leave any blocker visible if a required current-period input is missing.

### Step 5 — automation only after manual E2E acceptance

Do not add another SEC schedule.

If later automation is approved, reuse the existing SHADOW schedule and add only the smallest post-collection handoff needed to invoke the already-tested normalization/PREVIEW path. Production APPLY remains separately permissioned unless policy is explicitly changed.

## Production boundary

This PR is safe to review without authorizing production writes.

A future instruction to **merge** this PR is not, by itself, authorization to:

- deploy an Edge Function;
- alter cron;
- execute APPLY;
- write canonical metrics;
- create a valuation run;
- change the Valuation Map;
- trade.
