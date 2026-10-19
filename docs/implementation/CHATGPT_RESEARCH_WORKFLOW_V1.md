# ChatGPT Research Workflow v1

Status: **PR1 — CONTRACT ONLY**  
Repository authority baseline: `FWIOS-CONTRACT-0.87.17`  
Foundation compatibility: `0.87`  
Production research-ingestion cutover: **NO**  
Human execution only: **YES**  
Auto trade: **NO**

## 1. Purpose

Define the controlled contract between the user, ChatGPT research, and FWIOS before any new research-ingestion implementation exists.

The target boundary is:

```text
User
  ↓
ChatGPT research
  ↓
PREVIEW / APPLY intent
  ↓
Controlled ingestion gateway (PR2)
  ↓
Validation
  ↓
Evidence + typed metrics
  ↓
Existing deterministic FWIOS gates
  ↓
Scanner / presentation
```

This contract does **not** create a new scoring engine, does not replace the existing Research Lifecycle contract, and does not grant ChatGPT direct write access to FWIOS research tables.

## 2. Authority and safety boundaries

Existing FWIOS authority remains unchanged:

- **Supabase** = system of record / state / deterministic logic.
- **GitHub** = logic / contracts / tests / migrations.
- **Google Sheets** = presentation / compatibility / reconciliation / audit / export.
- **ChatGPT** = research, evidence collection, interpretation, summarization, and controlled orchestration.

Mandatory invariants:

1. ChatGPT must not directly write to `fwios.evidence_records`, `fwios.metric_observations`, `fwios.research_candidates`, thesis tables, valuation tables, scoring tables, or scanner tables.
2. ChatGPT must not mutate transactions, holdings, quantities, cost basis, cash, realized P&L, approval state, or execution state.
3. Research never places orders. `auto_trade=false` and human execution remain mandatory.
4. Existing deterministic lifecycle, valuation, quality-hardening, scoring, and readiness gates remain authoritative.
5. Missing critical data must fail closed. ChatGPT must not invent values to make a candidate pass.
6. Broad-universe research remains shallow/selective. Full Thesis remains a scarce state.
7. U1 — S&P 500 Membership Foundation remains paused until separately reactivated by the user.
8. Technical market-data / entry-timing work is outside PR1 and must remain separate from fundamental research and valuation.

## 3. Supported command intents

PR1 defines intent semantics. Exact natural-language phrasing may vary, but the resolved intent must match one of the following behaviors.

| User intent | Default mode | Contract behavior |
|---|---|---|
| `Scan Market` | PREVIEW | Read current scanner/state and identify candidates. No production write. |
| `Research ADBE` | PREVIEW | Research one ticker and return structured evidence/metrics preview. |
| `Refresh ADBE Research` | PREVIEW | Re-research with current sources. Refresh does not imply a production write. |
| `Research Top 5 Candidates` | PREVIEW | Research the selected candidate set and return a combined preview. |
| `Update ADBE into FWIOS` | APPLY | Explicit production-ingestion intent for ADBE, subject to the controlled gateway and validation. |
| `Research ADBE and update FWIOS` | APPLY | Research may occur first, then validated payload may enter the APPLY path because write intent is explicit. |
| `Update Research to FWIOS` | APPLY only when target/batch is unambiguous | If the target research batch is unclear, fail closed and do not write. |

### 3.1 Default rule

**PREVIEW is the default.**

Research, refresh, scan, analyze, compare, review, investigate, or summarize instructions do not imply production mutation.

### 3.2 APPLY rule

APPLY requires explicit user intent to persist/update/apply the research into FWIOS.

Examples of explicit APPLY intent include:

- `Update ADBE into FWIOS`
- `Apply this ADBE research to FWIOS`
- `Save this research into FWIOS`
- `Research ADBE and update FWIOS`

An explicit APPLY instruction does not bypass validation. It only authorizes the controlled ingestion path.

If the user has already explicitly requested APPLY and the target is unambiguous, the workflow does not require an artificial second confirmation solely because PREVIEW validation occurs internally first.

### 3.3 No implicit APPLY

These remain PREVIEW:

- `Research ADBE`
- `Refresh ADBE`
- `Check ADBE again`
- `Find updated revenue and guidance`
- `Scan FWIOS`

No scheduled or background research write is authorized by this contract.

## 4. Existing Research Lifecycle compatibility

PR1 must coexist with `POL-RESEARCH-LIFECYCLE-V1`.

Current lifecycle states remain:

```text
UNIVERSE
SCREENED
WATCH
RESEARCH_CANDIDATE
FULL_THESIS
PORTFOLIO
REJECTED
ARCHIVED
```

Research commands do **not** directly promote or demote lifecycle state.

Important rules:

- broad universe remains shallow;
- `RESEARCH_CANDIDATE` is the targeted-research state;
- promotion into `FULL_THESIS` remains subject to existing deterministic transition/archetype rules;
- `REJECTED` retains decision memory and reactivation conditions;
- `PORTFOLIO` remains tied to reconciled holdings;
- lifecycle demotion must not delete prior evidence, thesis, decision, approval, or portfolio audit lineage;
- `production_read_cutover=false` remains in force until a later explicit cutover.

PR1 may collect research useful to lifecycle decisions, but it must not silently perform those transitions.

## 5. Source policy

### 5.1 Precedence

For canonical investment facts, prefer:

```text
SEC / regulator filings / company IR / company-issued earnings material
    ↓
Other direct primary company or market sources
    ↓
High-quality secondary sources
```

Existing source-routing policy remains authoritative where it is stricter.

### 5.2 Critical fact classes

The following must use suitable primary/Tier-A evidence when used as canonical production facts:

- reported financials;
- company guidance;
- balance-sheet facts;
- debt / cash facts;
- free cash flow and other reported cash-flow facts;
- share count / dilution / SBC facts when used in hardening or valuation;
- resource/technical-report facts where the active model depends on them.

Secondary sources may add context but must not replace required primary evidence for critical production metrics.

### 5.3 Material news

Material news may use high-quality Tier-A/B secondary context when primary confirmation is unavailable, but:

- source class must remain explicit;
- unconfirmed claims must not be promoted to verified canonical facts;
- conflicting primary evidence overrides lower-tier summaries.

### 5.4 Market price boundary

Canonical market price belongs to the FWIOS Market Data Service.

ChatGPT web research must not create or overwrite canonical market-price observations from arbitrary webpages.

A research report may discuss market context, but price-sensitive gates must use the existing verified market-data path.

## 6. Research payload contract

PR1 defines the payload shape expected by PR2. PR1 does not implement the gateway.

Conceptual schema:

```json
{
  "schema_version": "chatgpt_research_payload_v1",
  "mode": "PREVIEW",
  "command": "Research ADBE",
  "ticker": "ADBE",
  "instrument_id": null,
  "research_as_of": "2026-10-19T00:00:00Z",
  "evidence": [],
  "metrics": [],
  "guidance": [],
  "risks": [],
  "research_summary": {},
  "validation_preview": {}
}
```

### 6.1 Identity fields

Required:

- `schema_version`
- `mode`
- `command`
- `ticker`
- `research_as_of`

`instrument_id` is optional in the ChatGPT payload and is never authoritative merely because ChatGPT supplied it. PR2 must resolve/verify ticker → canonical instrument identity.

### 6.2 Evidence item

Each evidence item should carry enough context to validate the claim:

```json
{
  "evidence_ref": "ev-local-001",
  "fact_class": "REPORTED_FINANCIALS",
  "claim": "Q3 FY2026 revenue was ...",
  "source_name": "Adobe Investor Relations",
  "source_url": "https://...",
  "source_type": "WEB_PRIMARY",
  "source_tier": "A",
  "retrieved_at": "2026-10-19T00:00:00Z",
  "reported_at": "2026-09-...",
  "reporting_period": "Q3 FY2026",
  "verification_status": "VERIFIED",
  "conflict_group": null,
  "notes": null
}
```

Requirements:

- source URL must be preserved;
- source type/tier must be explicit;
- retrieval date/time must be explicit;
- reporting period or as-of context must be explicit when applicable;
- critical facts must not be marked VERIFIED without suitable evidence;
- `evidence_ref` is payload-local only; PR2 owns production idempotency and durable identifiers.

### 6.3 Metric item

Metrics must be typed and period-aware:

```json
{
  "metric_code": "REVENUE",
  "value_type": "NUMERIC",
  "value_numeric": 5.41,
  "value_text": null,
  "value_boolean": null,
  "unit": "USD_B",
  "currency": "USD",
  "period_kind": "QUARTER",
  "period_start": null,
  "period_end": null,
  "fiscal_label": "Q3 FY2026",
  "reported_at": "2026-09-...",
  "evidence_refs": ["ev-local-001"],
  "verification_status": "VERIFIED"
}
```

Rules:

- exactly one typed value field should be populated;
- unit must be explicit for numeric values;
- currency must be explicit for monetary values;
- reporting period/as-of semantics must be explicit;
- every critical metric must reference supporting evidence;
- ChatGPT must not invent a metric code if no compatible canonical meaning can be established; mark it for review instead.

### 6.4 Guidance item

Guidance must remain distinguishable from reported actuals:

```json
{
  "guidance_type": "REVENUE",
  "period": "Q4 FY2026",
  "value_low": null,
  "value_high": null,
  "unit": "USD_B",
  "currency": "USD",
  "statement": "...",
  "evidence_refs": ["ev-local-002"],
  "verification_status": "VERIFIED"
}
```

Canonical guidance requires company-issued primary evidence.

### 6.5 Risk item

Risks are research context, not an AI-generated investment score:

```json
{
  "category": "COMPETITION",
  "statement": "...",
  "evidence_refs": ["ev-local-003"],
  "status": "OPEN"
}
```

PR1 must not invent a numeric risk score or use qualitative research prose to bypass deterministic FWIOS scoring/gates.

### 6.6 Research summary

The summary may contain:

- key findings;
- thesis-supporting evidence;
- thesis-challenging evidence;
- open questions;
- missing evidence;
- material conflicts;
- recommended next research actions.

It must not contain a freely invented production scanner score, valuation confidence, quality-hardening result, readiness status, or buy/sell execution instruction.

## 7. Validation and fail-closed rules

The controlled workflow must fail closed on critical ambiguity.

| Condition | Required behavior |
|---|---|
| Ticker cannot resolve to a canonical instrument | BLOCK |
| Critical fact has no source URL | BLOCK that fact |
| Critical reported financial/guidance fact lacks required primary evidence | BLOCK |
| Monetary metric lacks unit or currency | BLOCK metric |
| Period-aware metric lacks reporting-period/as-of context | BLOCK metric |
| Evidence is stale or freshness cannot be established for a freshness-sensitive fact | REVIEW or BLOCK; never silently treat as fresh |
| Two credible sources materially conflict | REVIEW/BLOCK until reconciled |
| Lower-tier evidence conflicts with an existing higher-tier VERIFIED fact | Do not overwrite higher-tier fact |
| Required data is missing | Preserve as missing; do not guess |
| Canonical market price is sourced only from arbitrary web research | Do not ingest as market price |
| No valid valuation model exists | Research may continue; valuation remains BLOCKED |
| Ingestion gateway is unavailable | APPLY is blocked; no direct table write fallback |

A high apparent investment score must never compensate for missing or blocked evidence.

## 8. PREVIEW contract

PREVIEW may:

- browse/research current sources;
- collect evidence;
- map candidate metrics;
- identify conflicts;
- identify stale/missing research;
- generate a validation preview;
- explain what would be eligible for ingestion.

PREVIEW must not mutate production.

Recommended response shape:

```text
Research completed: ADBE

Evidence
- 8 collected
- 7 PASS
- 1 REVIEW
- 0 BLOCKED

Metrics
- 6 mapped
- 5 PASS
- 1 REVIEW

Open blockers
- <reason if any>

Mode: PREVIEW
Production changes: NONE
```

## 9. APPLY contract

APPLY is authorization to attempt controlled ingestion, not permission for arbitrary writes.

Target PR2 interface:

```text
ChatGPT research payload
  ↓
preview_research_ingest_v1(...)
  ↓
deterministic validation
  ↓
apply_research_ingest_v1(...)
  ↓
approved FWIOS evidence / metric state
```

Names above are the expected conceptual interface for PR2; PR1 does not claim that these functions already exist.

### 9.1 Before PR2 exists

If the user gives explicit APPLY intent while no controlled ingestion gateway is deployed:

```text
APPLY_BLOCKED_GATEWAY_NOT_IMPLEMENTED
```

The workflow must not fall back to direct writes into research tables.

### 9.2 After PR2 exists

APPLY must:

1. resolve canonical instrument identity;
2. validate evidence source class/tier;
3. validate URLs and retrieval/reporting dates;
4. validate metric type/unit/currency/period;
5. detect conflicts and precedence violations;
6. run idempotency/deduplication rules owned by PR2;
7. reject blocked critical facts;
8. persist only through the controlled gateway;
9. return an ingestion receipt/result;
10. leave downstream lifecycle/readiness/valuation/scoring transitions to deterministic FWIOS logic.

## 10. Scanner and Sheet boundary

Research may eventually feed Scanner v2 through validated Supabase state.

PR1 must not:

- write scanner scores directly;
- place core investment logic in Google Sheet formulas;
- write research directly into `S&P500 Scanner` or `_Scanner_Data`;
- treat the current 64-stock universe as full S&P 500 coverage;
- reactivate U1 automatically.

Supabase remains the source of truth; Google Sheet remains presentation.

## 11. Explicit non-goals

PR1 does **not** implement:

- research ingestion RPCs/functions;
- new database tables or migrations;
- direct table writes;
- idempotency persistence;
- automatic lifecycle transitions;
- new valuation models;
- readiness gates;
- Scanner v2;
- Sheet v2;
- technical indicators or entry-timing logic;
- S&P 500 universe expansion;
- research cron/scheduler;
- automatic trading;
- autonomous buy/sell recommendations or execution.

Those belong to later PRs/tasks.

## 12. Contract acceptance scenarios

PR1 is accepted when the following semantics are unambiguous:

1. `Research ADBE` → PREVIEW only.
2. `Refresh ADBE Research` → PREVIEW only.
3. `Research Top 5 Candidates` → PREVIEW only.
4. `Research ADBE and update FWIOS` → explicit APPLY intent, but only through the controlled gateway.
5. APPLY before PR2 exists → blocked, with no direct-write fallback.
6. Missing Tier-A evidence for a critical reported metric → blocked, not guessed.
7. Secondary context cannot overwrite a higher-tier VERIFIED fact.
8. Monetary metrics require value + unit + currency + period/as-of context.
9. Research cannot directly alter lifecycle state, scanner score, valuation, holdings, accounting, approval, or execution.
10. Human execution and `auto_trade=false` remain intact.

## 13. PR1 Definition of Done

PR1 is complete when this contract is merged and reviewers can answer, without ambiguity:

- what ChatGPT is allowed to research;
- which commands are PREVIEW versus APPLY;
- what explicit user intent is required for production ingestion;
- which source classes are acceptable for critical facts;
- what the research payload must contain;
- what conditions fail closed;
- what ChatGPT may never write directly;
- how the future PR2 gateway must sit between ChatGPT and FWIOS state.

No production data change is required or permitted for PR1.
