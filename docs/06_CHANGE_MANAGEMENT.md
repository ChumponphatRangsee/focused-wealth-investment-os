# 06 — Change Management

Contract version: **FWIOS-CONTRACT-0.87.0**

This system is intentionally fail-closed. Changes to formulas, metric definitions, normalization, valuation routing or scoring can silently alter investment decisions, so documentation and live-system changes must move together.

## Version scheme

Use:

`FWIOS-CONTRACT-<foundation>.<contract-patch>`

Current:

`FWIOS-CONTRACT-0.87.0`

The live sheet's foundation version is `0.87`.

### When to increment foundation compatibility

Increment the foundation version when a material system architecture or production-logic change occurs, including:

- changing canonical data flow;
- changing production scoring weights;
- changing hard-gate semantics;
- adding/removing a production valuation route;
- changing blocker-orchestrator state semantics;
- changing source precedence or evidence requirements;
- changing sector-loop state machine behavior.

### When to increment contract patch only

A patch-only update is appropriate for:

- clarifying documentation without changing live behavior;
- correcting stale wording;
- adding examples that do not alter rules;
- fixing repository structure or references.

## Required change workflow

For a material live-system change:

1. Read current live foundation and repository contract.
2. Define the intended economic/system behavior before editing formulas.
3. Update the live system.
4. Run regression and error checks.
5. Update `System_Foundation` version/status if compatibility changed.
6. Update this repository in the same workstream.
7. Update `VERSION` and `contracts/system-contract.yaml`.
8. Update the documentation handshake row in `System_Foundation`.
9. Only then allow new autonomous sector runs.

## Regression requirements

Changes to normalization, valuation or scoring must test at least:

- formula errors: `#REF!`, `#DIV/0!`, `#VALUE!`, `#N/A`;
- metric coverage gates;
- valuation readiness;
- mispricing classification;
- chase/FOMO fail-closed behavior;
- portfolio gate behavior;
- candidate limits;
- blocker dependency logic.

Phase 0.87 currently uses explicit reference regressions around:

- ISRG — MEDTECH
- EOG — E&P
- BKR — OFS
- CAVA — Restaurant
- TPR — Branded Retail

A changed reference output is not automatically a failure if the economics were intentionally changed, but the reason and new expected result must be documented.

## Definition changes

A metric-definition change is a schema change, not a cosmetic edit.

Example: `comparable_sales_growth` was changed to `underlying_sales_growth` for Branded Retail where company disclosure did not support a clean company-wide comparable-sales KPI.

When changing a metric definition:

1. update `Sector_Criteria`;
2. update source evidence / canonical mapping as needed;
3. update normalization definition tags;
4. update model contracts;
5. regression-test affected companies;
6. update this repository.

Never silently coerce a company-specific disclosure into a different canonical metric name.

## Model implementation rule

Adding a `Valuation Model ID` to `Sector_Criteria` does not make the model live.

A model is production-live only after:

- required metric contract is defined;
- evidence/canonical mapping works;
- normalization is defined;
- model formulas are implemented;
- sanity/readiness gates exist;
- regression checks pass;
- `System_Foundation` recognizes the route as implemented.

Until then, it must fail closed.

## No silent backward incompatibility

If repository contract and live foundation are incompatible:

- set documentation handshake to BLOCKED;
- do not start a new autonomous sector;
- repair the mismatch first.

## Public repository hygiene

This repository may be public. Do not commit:

- exact live personal holdings/allocation snapshots;
- account numbers;
- broker credentials or API secrets;
- private contact data;
- sensitive personal financial details not required for the system contract.

The repository should contain system rules and architecture, while live personal state remains in the connected portfolio tracker.
