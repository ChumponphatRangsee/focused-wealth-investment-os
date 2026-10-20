# PR4 — Research Readiness & Fail-Closed Gates v1

Date: 2026-10-19  
Status: **LIVE / ADDITIVE / NO SCANNER CUTOVER**  
Policy: `POL-RESEARCH-READINESS-V1`  
Read model: `fwios.v_research_readiness_current_v1`

## Goal

Create the deterministic bridge between validated research state and the future Scanner v2.

```text
validated evidence / research state
  ↓
research readiness
  ↓
latest production-eligible valuation
  ↓
current-lineage Quality Hardening
  ↓
canonical verified price
  ↓
Investment Review Ready
```

PR4 does not replace `fwios.v_scanner_current_v1`. It exposes the gate that PR5 must consume.

## Verified pre-change state

Before implementation:

- GitHub `main` was identical to post-PR2 commit `02aee6017ee2693475447c1b692f77c513eb8ed6`;
- `POL-CONTROLLED-RESEARCH-INGEST-V1` was ACTIVE;
- PR2 live migrations and PREVIEW/APPLY functions were present;
- existing research, valuation, Quality Hardening and canonical market-price objects were inspected and reused;
- U1 / full S&P 500 expansion remained paused.

No parallel lifecycle, valuation engine, hardening engine or market-price path was created.

## Readiness hierarchy

The output hierarchy is:

1. `DISCOVERY_READY`
2. `RESEARCH_READY`
3. `VALUATION_READY`
4. `QUALITY_HARDENED`
5. `INVESTMENT_REVIEW_READY`

A downstream state cannot be ready when its upstream state is blocked.

## Research Ready

Research readiness uses two deterministic compatibility routes.

**Legacy candidate route**

- an existing `research_candidates` row must exist;
- `evidence_gate=PASS`;
- evidence and verified primary/Tier-A evidence must exist;
- unresolved conflict / explicit stale evidence fails closed;
- `research_candidates.as_of_date` must be within the 120-day policy window.

**Controlled PR2 route**

- an APPLIED controlled-ingest receipt must exist;
- the receipt must contain evidence;
- the receipt must contain at least one validated canonical metric;
- the receipt must contain verified primary/Tier-A evidence;
- at least one metric must have a `reported_at`, `as_of_date`, or `period_end` date within the 120-day research window.

For the controlled route, `research_as_of` comes from the metric's source-period date, not the receipt/ingest timestamp. A filing from 2024 ingested in 2026 therefore remains stale. A receipt with `metrics=[]` remains `RESEARCH_NOT_READY`.

This preserves legacy compatibility while allowing PR2-controlled APPLY to qualify without mutating `research_candidates`, and closes the review finding where ingest time could incorrectly make old/incomplete research look fresh.

## Valuation Ready

Valuation is ready only when Research Ready is true and the latest `production_eligible=true` valuation run:

- has `valuation_readiness` of PASS/READY;
- passes router, valuation and schema gates;
- is within the 180-day policy window.

The production-eligible filter is applied before choosing the latest run, so a newer shadow/experimental run cannot displace a still-valid production valuation.

No new valuation model is introduced.

## Quality Hardened

Quality Hardened is true only when:

- Valuation Ready is true;
- the latest hardening snapshot has `overall_gate=PASS`;
- the hardening snapshot references the current latest `valuation_run_id`;
- the hardening snapshot is within the 180-day policy window.

The lineage rule is intentionally strict. A previously passing hardening snapshot becomes stale after a new valuation run until hardening is rerun against that valuation.

At rollout this correctly identified ADBE as `QUALITY_HARDENING=STALE`: the latest hardening snapshot still referenced the older valuation run.

## Lifecycle gate status

`POL-RESEARCH-LIFECYCLE-V1` remains `production_read_cutover=false`.

PR4 therefore does **not** invent a second lifecycle or pretend that a canonical per-stock lifecycle read gate is active. The readiness view exposes:

- `lifecycle_gate_enforced=false`;
- `lifecycle_gate_status=DEFERRED_NO_PRODUCTION_READ_CUTOVER`.

Lifecycle state remains preserved and reusable, but enforcing it as a PR4 production gate is deferred until the existing lifecycle policy has an authoritative production read cutover.

## Price Ready

Price readiness uses only `fwios.v_market_daily_close_latest`.

Requirements:

- positive canonical close;
- verification status in `VERIFIED` or `PRIMARY_ONLY`;
- provenance `PASS`;
- session date no older than 7 days.

PR4 does not ingest webpage prices or create another price source.

## Investment Review Ready

`investment_review_ready = quality_hardened AND price_ready`.

`scanner_score_eligible` is exactly equal to `investment_review_ready`.

PR5 must therefore apply:

```text
scanner_score_eligible = false
  → scanner_score = NULL
  → scan_rank = NULL
```

PR4 deliberately does not change Scanner v1 so rollout stays additive and rollback-safe.

## Blocking reasons

The bounded PR4 blocker taxonomy is:

- `READINESS_POLICY_NOT_ACTIVE`
- `CONFLICTING_EVIDENCE`
- `MISSING_PRIMARY_EVIDENCE`
- `STALE_RESEARCH`
- `RESEARCH_NOT_READY`
- `VALUATION_BLOCKED`
- `QUALITY_HARDENING_FAIL`
- `PRICE_NOT_VERIFIED`

`blocking_reason` exposes the first deterministic blocker and `blocking_reasons` preserves all active blockers.

## Live rollout result

Migration:

- `research_readiness_fail_closed_v1`
- `research_readiness_fail_closed_v1_hardening`

Acceptance:

- **21/21 PASS**

Current live snapshot immediately after rollout:

| Metric | Count |
| --- | ---: |
| Active Stock instruments | 64 |
| Research Ready | 27 |
| Valuation Ready | 27 |
| Quality Hardened | 1 |
| Investment Review Ready | 1 |
| Scanner-score eligible | 1 |

Examples:

- ACN → `INVESTMENT_REVIEW_READY`;
- ADBE → `VALUATION_READY`, blocked because Quality Hardening lineage is stale;
- EOG → `VALUATION_READY`, blocked because Quality Hardening is FAIL;
- PINS / RDDT → `VALUATION_READY`, blocked because Quality Hardening is REVIEW;
- JPM / NFLX / V → `VALUATION_READY`, blocked because Quality Hardening is missing.

## Acceptance coverage

The 21 checks cover:

1. policy active and human-only/no-cutover config;
2. security-invoker view;
3. service-role-only access;
4. active-stock universe parity;
5. one row per canonical instrument;
6. strict readiness hierarchy;
7. research fail-closed rules;
8. valuation fail-closed rules;
9. hardening must PASS;
10. hardening must reference latest valuation;
11. canonical price fail-closed rules;
12. exact Investment Review gate;
13. blocked rows always expose a reason;
14. scanner-score eligibility equals Investment Review readiness;
15. blocker taxonomy remains bounded;
16. no portfolio/accounting/approval/execution dependency in the view;
17. controlled receipt with `metrics=[]` remains blocked;
18. old source-period metric ingested today remains stale;
19. fresh controlled evidence + canonical metric can become Research Ready;
20. newer non-production/shadow valuation cannot displace the latest production valuation;
21. lifecycle gating is explicitly deferred while the lifecycle policy has no production read cutover.

## Security / advisor result

The new view is `security_invoker=true`, SELECT is revoked from PUBLIC/anon/authenticated and granted to `service_role`.

Post-hardening Supabase security/performance advisors returned no finding that references the PR4 readiness view. Existing project-wide advisor findings predate this PR and are outside PR4 scope.

## Safety boundary

PR4 does not mutate:

- evidence or metric rows;
- `research_candidates`;
- lifecycle state;
- valuation runs;
- hardening snapshots;
- Scanner v1 score/rank;
- holdings or transactions;
- quantities or cost basis;
- cash or P&L;
- approval or execution state.

`auto_trade=false`; human execution only.

## PR2 production state remains clean

After PR4 acceptance:

- research-ingest receipts: 0;
- `AI-EV-%` evidence rows: 0;
- `AI-OBS-%` metric observations: 0.

No test research payload was left in production.

## Next step

PR5 may now create Scanner v2 and consume `fwios.v_research_readiness_current_v1`.

PR5 must not expose a scanner score or rank for any row where `scanner_score_eligible=false`.

U1 remains paused.
