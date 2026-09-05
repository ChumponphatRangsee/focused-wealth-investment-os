# 04 — Blocked Resolution Orchestrator

Contract version: **FWIOS-CONTRACT-0.87.0**

The central blocker queue is the only durable mechanism for root-cause remediation.

Live location: `Data_Quality_Gates` columns **R:AJ**.

## Queue schema

| Column | Meaning |
|---|---|
| R | Block ID |
| S | Ticker |
| T | Company |
| U | Blocked Layer |
| V | Metric / Model |
| W | Blocked Reason |
| X | Missing Inputs |
| Y | Resolution Action |
| Z | Priority |
| AA | Retry Trigger |
| AB | Last Checked |
| AC | Current Status |
| AD | Resolution Note |
| AE | Dependency Block ID |
| AF | Retry Mode |
| AG | Retry Frequency |
| AH | Next Eligible Check |
| AI | Resolver |
| AJ | Orchestrator State |

## Supported blocker layers

Typical root-cause layers include:

- SOURCE
- DEFINITION
- CANONICAL
- NORMALIZATION
- MODEL

A blocker is not the same thing as a rejected investment thesis. It means the system cannot safely complete a required production step with current evidence/logic.

## State machine

### CLOSED
Current Status is PASS. No resolver action required.

### WAIT_DEPENDENCY
A dependency block exists and has not passed yet.

### WAIT_RETRY
Dependency is satisfied, but the next eligible retry time/event has not arrived.

### READY
Dependency is satisfied and the blocker is eligible for resolution work now.

## Dependency rule

A dependent blocker may not run until its dependency has Current Status = PASS.

Example pattern:

```text
CANONICAL → NORMALIZATION → MODEL
```

Do not bypass a normalization blocker merely because the model formula could technically run.

## Retry modes

Current queue logic supports durable modes such as:

- `CLOSED`
- `DEPENDENCY_PASS`
- `SOURCE_REFRESH`
- `EARNINGS_OR_RESEARCH`
- manual/event-driven variants

Retry frequency may resolve to policies such as:

- NONE
- EVENT
- WEEKLY_OR_EVENT
- MONTHLY_OR_EVENT
- MANUAL

Explicit filings, earnings or new primary evidence may override a calendar wait where the queue policy permits it.

## Resolver contract

The resolver type should be derived from the blocked layer rather than from ticker-specific scripts.

Conceptual examples:

- `SOURCE_RESOLVER`
- `DEFINITION_RESOLVER`
- `CANONICAL_RESOLVER`
- `NORMALIZATION_RESOLVER`
- `MODEL_RESOLVER`

Do not create a separate permanent automation for every company when the central queue can express the problem.

## Resolution protocol

For each READY blocker:

1. Re-read current live state and dependency.
2. Identify the exact missing evidence or logic.
3. Search primary/current sources where the blocker requires new external evidence.
4. Write raw evidence first when applicable.
5. Canonicalize only evidence-supported metrics.
6. Normalize only with an explicit method/version.
7. Implement model logic only after required inputs pass.
8. Run regression/sanity checks.
9. Update Last Checked, Current Status and Resolution Note.
10. Allow formulas to close downstream dependent blockers.

## Fail-closed behavior

If a credible input cannot be found, leave the blocker open.

Forbidden:

- inventing maintenance capex;
- inferring a post-acquisition balance sheet from an incompatible pre-close snapshot without an explicit qualified bridge;
- silently changing metric definitions;
- using analyst estimates as canonical reported facts;
- declaring a blocker resolved because a stock looks attractive.

## Historical initial Phase 0.87 snapshot

The initial Phase 0.87 baseline reported:

- `0 OPEN ROOT BLOCKERS`
- `0 READY / 0 WAIT_DEP / 0 WAIT_RETRY / 8 CLOSED`

This is a point-in-time snapshot only. Future sector runs must add newly discovered root blockers into the same queue.

## Current snapshot

As of the 2026-09-05 Communication Services closeout, seven root blockers remain. Use the master roadmap and live Supabase controller for the current resolution order; the initial zero-blocker baseline above is historical.
