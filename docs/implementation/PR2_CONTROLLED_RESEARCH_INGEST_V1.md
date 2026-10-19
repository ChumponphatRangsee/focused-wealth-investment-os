# PR2 — Controlled Research Ingestion v1

Date: 2026-10-19  
Status: **LIVE / ADDITIVE GATEWAY**  
Policy: `POL-CONTROLLED-RESEARCH-INGEST-V1`  
Depends on: `docs/implementation/CHATGPT_RESEARCH_WORKFLOW_V1.md`

## Goal

Create the controlled boundary between ChatGPT research and FWIOS production research state.

```text
ChatGPT structured research payload
  ↓
fwios.preview_research_ingest_v1(payload)
  ↓
deterministic validation
  ↓
fwios.apply_research_ingest_v1(payload)
  ↓
evidence_records + metric_observations + audit receipt
```

ChatGPT does not receive a free-form direct-write path to production research tables.

## Live objects

Added:

- `fwios.research_ingest_receipts_v1`
- `fwios.research_source_tier_rank_v1(text)`
- `fwios.research_try_timestamptz_v1(text)`
- `fwios.research_try_date_v1(text)`
- `fwios.research_evidence_id_v1(uuid,jsonb)`
- `fwios.research_observation_key_v1(uuid,jsonb,text)`
- `fwios.preview_research_ingest_v1(jsonb)`
- `fwios.apply_research_ingest_v1(jsonb)`

Live migrations:

- `controlled_research_ingest_v1`
- `controlled_research_ingest_v1_index_hardening`

## Validation boundary

PREVIEW validates at least:

- payload schema and explicit PREVIEW/APPLY mode;
- ticker → active canonical Stock instrument;
- research timestamp;
- evidence source routing / primary-source requirements;
- HTTPS source URL;
- source tier;
- retrieval/reporting timestamps;
- reporting period;
- verification state;
- unresolved conflicts;
- canonical metric code;
- typed metric value;
- source-unit → canonical-unit compatibility;
- currency for monetary metrics;
- period semantics;
- evidence linkage;
- conflicting existing VERIFIED observations.

Critical ambiguity fails closed.

## Source precedence

The gateway reuses `fwios.source_routing_rules`.

For critical reported financials, guidance, balance-sheet facts and other fact classes whose route requires primary evidence:

- lower-tier evidence is blocked from canonical metric ingestion;
- a lower-quality source cannot overwrite a higher-quality VERIFIED production row;
- existing evidence/observations are never updated by this gateway.

## Idempotency

Three layers prevent duplicate writes:

1. payload fingerprint → one APPLY receipt;
2. deterministic `evidence_id`;
3. deterministic `observation_key`.

Repeated APPLY of the exact same accepted payload returns `NOOP_ALREADY_APPLIED`.

Writes use insert-only conflict handling. Existing rows are not overwritten.

## What APPLY writes

A valid explicit APPLY may add:

- new evidence rows to `fwios.evidence_records`;
- new typed observations to `fwios.metric_observations`;
- one immutable-style audit receipt to `fwios.research_ingest_receipts_v1`.

Research risks, guidance context and research summary are preserved in the receipt payload. They do not directly create scores or alter candidate state. Canonical guidance should be represented as a validated guidance metric when required downstream.

## What PR2 does not write

PR2 does not mutate:

- `fwios.research_candidates` scores/gates;
- lifecycle state;
- scanner score/rank;
- valuation outputs;
- holdings;
- transactions;
- quantity;
- cost basis;
- cash;
- realized P&L;
- approval state;
- execution state.

`auto_trade=false`; human execution only.

## Security

Gateway functions are `SECURITY INVOKER`.

EXECUTE is revoked from:

- `PUBLIC`
- `anon`
- `authenticated`

and granted to `service_role`.

`fwios.research_ingest_receipts_v1` has RLS enabled and no public/anon/authenticated table grants.

## Acceptance

Transactional live acceptance: **15/15 PASS**.

Coverage:

1. policy active;
2. valid preview passes;
3. preview is non-mutating;
4. canonical identity resolves;
5. gateway is SECURITY INVOKER;
6. RPC execution is service-role only;
7. invalid URL blocks;
8. lower-tier critical evidence blocks;
9. unknown metric blocks;
10. APPLY requires explicit APPLY mode;
11. accepted APPLY writes only gateway-owned research state;
12. research candidate state remains unchanged;
13. repeat APPLY is idempotent;
14. conflicting VERIFIED metric is blocked;
15. receipt RLS is enabled.

The acceptance APPLY ran inside a database transaction and was rolled back.

Post-test production verification:

- research ingest receipts: 0;
- `AI-EV-%` test evidence: 0;
- `AI-OBS-%` test observations: 0.

No test research payload remains in production.

## Performance advisor

The receipt `instrument_id` foreign key has a covering index:

`research_ingest_receipts_v1_instrument_idx (instrument_id, applied_at desc)`.

The remaining advisor message for this index is only the expected fresh-index `unused_index` INFO.

## Rollout state

The gateway is live and ready for a future real user-authorized APPLY payload.

No real ChatGPT research payload has been applied yet.

PR1 remains the command/payload contract. PR2 is its controlled persistence gateway.

## Next Feature-1 step

PR4 — Research Readiness & Fail-Closed Gates.

PR4 must consume validated research state and determine whether a stock is Discovery Ready, Research Ready, Valuation Ready, Quality Hardened, or Investment Review Ready without allowing a high score to mask blocking data.
