# FWIOS ACN v2 APPLY + Shadow Valuation Receipt

Date: **2026-10-26 (Asia/Bangkok)**

## Git state

- PR #77 merged to `main`.
- PR #78 retargeted to `main` and merged.
- Live Supabase migration `20261026101318 valuation_period_semantics_v2` is represented in GitHub.

## Controlled research APPLY

Exact reviewed ACN current-period payload was validated again with `mode=APPLY` before mutation.

Validation result:

- overall status: PASS
- evidence: 2/2 PASS, Tier A
- metrics: 7/7 PASS
- blockers: 0
- warnings: 0
- APPLY payload fingerprint: `451a19fcd56e8487161a173ed8ecc340`

APPLY receipt:

- receipt id: `df7bbf48-a141-429c-9b02-f488767eb3e2`
- evidence inserted: 2
- canonical metric observations inserted: 7
- portfolio mutation: false
- scanner score mutation: false
- research candidate mutation: false
- auto trade: false
- human execution only: true

Second execution of the same payload returned `NOOP_ALREADY_APPLIED`, confirming idempotency.

## Canonical ACN v2 resolver

After APPLY, the contract-driven resolver returned:

- required selectors: **7**
- required PASS: **7**
- required BLOCKED: **0**
- optional diagnostics PASS: **3/3**

Required canonical observations now resolve to:

| Input | Value | Period |
|---|---:|---|
| FCF guidance low | 11.0 USD B | FY2027 guidance |
| FCF guidance midpoint | 11.4 USD B | FY2027 guidance |
| FCF guidance high | 11.8 USD B | FY2027 guidance |
| FCF actual/LTM | 11.620598 USD B | FY2026 ended 2026-08-31 |
| Net cash | 2.726011 USD B | 2026-08-31 |
| Shares outstanding | 596.1 M | 2026-08-31 |
| Revenue growth guidance LC midpoint | 4.5% | FY2027 guidance |

## Immutable shadow valuation run

Run created:

`VAL-SHADOW-ACN-ITSERV-V2-20261026`

Properties:

- model version: `IT_SERVICES_FCF_COMPOUNDER_V1::2.0`
- `production_eligible=false`
- model decision: `SHADOW VALIDATION ONLY - NO PRODUCTION CUTOVER`
- research receipt and payload fingerprint stored in run metadata
- 10/10 valuation inputs PASS
- 7/7 required inputs PASS
- 10 resolved metric-input lineage edges
- no decision/trading edge created

Valuation:

| Scenario | Production v1 | Shadow v2 | Change |
|---|---:|---:|---:|
| Bear | 168.31587961 | 171.98535827 | +2.18% |
| Base | 225.49896206 | 232.65156828 | +3.17% |
| Bull | 312.92478576 | 325.56851356 | +4.04% |
| Probability-weighted | 233.05964737 | 240.71425210 | +3.28% |

Shadow reference price: 249.415. Shadow probability-weighted upside: approximately **-3.49%**.

## Production boundary verification

The existing `fwios.v_dashboard_valuation_map` explicitly filters `valuation_runs.production_eligible=true`.

Post-shadow verification confirms ACN Dashboard still reads:

- run: `VAL-SUPA-ACN-ITSERV-20260905`
- production model: v1
- PW Fair Value: 233.0596473725

Therefore the shadow run did **not** alter the user-facing production valuation.

## Next gated decision

The technical prerequisites for ACN v2 production cutover are now satisfied at the data/resolver/shadow-validation level.

Production cutover is still a separate decision and should include:

1. explicit review of v1 vs v2 lineage and model-policy intent;
2. promotion of v2 from EXPERIMENTAL only if approved;
3. creation/designation of a production-eligible v2 valuation run;
4. validation that Valuation Map changes only after promotion;
5. rollback path to v1 retained;
6. no automatic trade execution.
