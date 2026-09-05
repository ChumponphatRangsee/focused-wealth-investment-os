# Human Approval / Cutover v1

Policy version: `POL-HUMAN-APPROVAL-V1`
Policy family: `HUMAN_APPROVAL`
Status: PRODUCTION ACTIVE after 30/30 regressions PASS.

## Purpose
Create a deterministic, auditable human-decision boundary after an immutable rebalancing recommendation. Approval is a decision record only; it never submits a broker order and never mutates portfolio accounting.

## State model
Recommendation Snapshot (immutable) → Approval Packet (immutable) → Approval Event (append-only).

Approvable packet scope: `PRODUCTION_USER_REQUESTED` only.
Non-actionable scopes: `CUTOVER_VALIDATION`, `SYNTHETIC_TEST`.

Terminal states: `APPROVED`, `REJECTED`, `EXPIRED`, `STALE`.
A stale or expired packet is never refreshed in place; a new recommendation/packet is required.

## Approval gates
An APPROVED event requires all of the following at event time:
1. packet scope is `PRODUCTION_USER_REQUESTED`;
2. packet state is `PENDING`;
3. `POL-HUMAN-APPROVAL-V1` is ACTIVE;
4. recommendation fingerprint still matches immutable recommendation rows;
5. recommendation traceability remains PASS;
6. latest reconciled portfolio batch is unchanged;
7. active opportunity ranking run is unchanged and PASS;
8. candidate Decision Snapshot/market price remains fresh and PASS;
9. every changed trim holding retains fresh production valuation lineage;
10. packet freshness deadline has not passed.

Missing/stale/conflicting lineage fails closed.

## Human / system events
- `APPROVED`: HUMAN actor only + revalidation PASS.
- `REJECTED`: HUMAN actor only.
- `EXPIRED`: SYSTEM actor only.
- `STALE`: SYSTEM actor only.
- terminal packets cannot transition again.

## Execution isolation
Every approval event stores and constrains:
- `broker_order_created = false`
- `portfolio_mutation_applied = false`

There is no auto-trade path in this policy. Broker price verification and a separate human execution step remain required for a real trade.

## Cutover validation
Cutover validation uses a `CUTOVER_VALIDATION` recommendation snapshot and packet. It proves the live chain:
`source transactions → reconciled positions → portfolio batch → candidate Decision Snapshot / holding valuation → Opportunity Ranking → recommendation snapshot → approval packet → execution isolation`.

A cutover-validation packet can never be approved.

Reference cutover lineage at activation:
- portfolio batch `PORTFOLIO-M2-20260905-01`
- 29/29 transactions reconciled
- 16/16 positions reconciled
- candidate PINS via `DEC-PINS-M2-20260905-V2`
- source NVDA via `VAL-NVDA-SEMIS-20260905`
- ranking `OPPRANK-M3-20260905-01`
- validation recommendation `REBAL-M3-CUTOVER-20260905-01`
- validation packet `APPROVAL-M3-CUTOVER-20260905-01`
- regression suite `REG-M3-APPROVAL-V1-*` = 30/30 PASS

These validation objects are non-actionable and are not investment instructions.