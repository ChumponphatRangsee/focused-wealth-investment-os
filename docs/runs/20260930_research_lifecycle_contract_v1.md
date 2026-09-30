# Research Lifecycle Contract v1 — 2026-09-30

Issue: #32  
Epic: #31  
Policy: `POL-RESEARCH-LIFECYCLE-V1`  
Contract: `FWIOS-CONTRACT-0.87.12`  
Foundation compatibility: `0.87`

## Scope

Activated the deterministic research lifecycle contract without cutting existing production research/decision read paths over to new lifecycle storage.

Implemented:
- 8 lifecycle states;
- legal transition graph;
- attention tiers 0–4;
- archetype coverage states;
- fail-closed deep-promotion rule for unsupported archetypes;
- decision-memory requirement for REJECTED;
- explicit reactivation requirement;
- reconciled-holding requirement for PORTFOLIO;
- immutable-lineage retention invariant;
- deterministic transition/profile functions;
- policy-regression registration.

Not implemented in this phase:
- instrument identity migration;
- company lifecycle backfill;
- read-path cutover;
- market/metric/thesis model migration;
- any portfolio transaction or trade execution.

## Live Supabase migration

Applied migration:
`research_lifecycle_contract_v1`

GitHub migration:
`migrations/20260930_research_lifecycle_contract_v1.sql`

## Regression

`tests/research/test_research_lifecycle_contract_v1.sql`

Result: **17/17 PASS**

Coverage includes:
- policy active and non-trading;
- exactly 8 lifecycle states;
- legal shallow transition;
- illegal shallow-to-deep jump;
- unsupported archetype blocks deep promotion;
- unsupported archetype does not force rejection;
- supported deep promotion passes;
- rejection requires decision memory;
- reactivation fails closed without trigger;
- reactivation passes with trigger;
- portfolio state requires reconciled holding;
- portfolio demotion blocked while still held;
- attention-tier mapping;
- REJECTED requires decision-memory payload;
- no production read cutover;
- registered policy regressions all PASS.

## Production parity verification

Before and after the migration, the following live outputs were identical:

### ADBE
- Revision Score: 47.5878
- Revision Gate: `FAIL - NEGATIVE FUNDAMENTAL REVISION`
- Hardening: PASS
- Thesis Health: WEAKENING / 86.5
- Opportunity Score: 89.7125
- Prebuy Gate: `BLOCKED - THESIS HEALTH`

### PINS
- Revision Score: 60.5531
- Revision Gate: PASS
- Hardening: REVIEW / confidence 0.775
- Thesis Health: WATCH / 87
- Opportunity Score: 87.7
- Prebuy Gate: `BLOCKED - PRICE VERIFY`

### Portfolio
- Open dashboard rows: 10
- Cost basis: THB 335,340.09
- Marked value at parity check: THB 353,270.59

No quantity, cost-basis, transaction, approval or trade mutation occurred.

## Result

Issue #32 acceptance criteria are satisfied at the contract/kernel layer.

Next task: **#33 — Canonical Instrument Identity v1**.
