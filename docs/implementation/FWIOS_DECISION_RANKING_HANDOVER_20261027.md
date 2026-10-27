# FWIOS MVP-1 — Decision / Ranking Lineage Handover

Date: **2026-10-27 Asia/Bangkok**  
Handover created from GitHub `main` merge commit: **51ab08328ce81af10c723482986b1bba0ed67bc3**  
Contract: **FWIOS-CONTRACT-0.87.23**  
Repository: `ChumponphatRangsee/focused-wealth-investment-os`

## 1. New-chat objective

Continue **FWIOS MVP-1 — Data Reliability / Decision Lineage Hardening**.

The upstream production path is now materially repaired through Quality Hardening:

```text
Evidence
  → Canonical Metrics
  → Period-aware Resolver
  → Valuation v2
  → Quality Hardening
  → Decision / Ranking    ← NEXT
```

Do **not** redesign valuation or retune Quality Hardening simply to make a ticker pass.

The next task is to diagnose and repair the **Decision / Ranking lineage refresh** so downstream decision state consumes the current production valuation + current hardening snapshots, while preserving fail-closed outcomes.

## 2. Mandatory starting reads

Read in this order before any write:

1. `AGENTS.md`
2. `contracts/system-contract.yaml`
3. `docs/CURRENT_STATUS.md`
4. `docs/implementation/FWIOS_QUALITY_HARDENING_REFRESH_BRIDGE_V1_20261027.md`
5. `docs/implementation/FWIOS_QUALITY_HARDENING_CANONICAL_EVIDENCE_V1_20261027.md`
6. `tests/decision/test_quality_hardening_refresh_bridge_v1.sql`
7. `tests/decision/test_quality_hardening_canonical_evidence_v1.sql`
8. `tests/decision/test_quality_durability_hardening_v1.sql`
9. Relevant Decision Snapshot / Opportunity Ranking migrations, functions and tests before modifying downstream state.

Always verify current GitHub `main` and live Supabase before relying on this dated handover.

## 3. What was completed

### 3.1 Valuation v2 production cutover

ACN, EOG and NFLX period-aware v2 models are production.

- ACN
  - production run: `VAL-PROD-ACN-ITSERV-V2-20261026`
  - model: `IT_SERVICES_FCF_COMPOUNDER_V1::2.0`
  - PW Fair Value: **240.7142520975**
- EOG
  - production run: `VAL-PROD-EOG-EP-V2-20261026`
  - model: `E&P_NORMALIZED_FCF_YIELD_V1::2.0`
  - PW Fair Value: **169.5415048027**
- NFLX
  - production run: `VAL-PROD-NFLX-STREAM-V2-20261026`
  - model: `STREAMING_FCF_DCF_V1::2.0`
  - PW Fair Value: **76.4521223650**

Promotion/rollback controls are service-role-only, human-authorized and idempotent.

Valuation production-cutover live SQL regression: **14/14 PASS, rollback verified**.

### 3.2 Quality Hardening Refresh Bridge v1

Live migration:

`20261027023035 quality_hardening_refresh_bridge_v1`

Policy:

`POL-QUALITY-HARDENING-REFRESH-V1`

The bridge repaired the stale integration between:
- current production valuation,
- canonical daily close,
- legacy-compatible price/mispricing snapshots,
- Quality Hardening lineage.

It does not change Quality Hardening thresholds.

Bridge-specific live SQL acceptance after the canonical evidence work: **10/10 PASS**.

### 3.3 Canonical Quality Hardening Evidence v1

Merged PR: **#84**  
Merge commit: **51ab08328ce81af10c723482986b1bba0ed67bc3**

Live migration:

`20261027031421 quality_hardening_canonical_evidence_v1`

Policy:

`POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1`

New controlled functions:
- `fwios.preview_quality_hardening_canonical_evidence_v1(ticker)`
- `fwios.preview_quality_hardening_canonical_refresh_v1(ticker)`
- `fwios.apply_quality_hardening_canonical_refresh_v1(ticker, human_authorized)`

Rules:
- only canonical `metric_observations` backed by Tier-A verified evidence can upgrade evidence-sensitive gates;
- shadow collection evidence cannot directly create a production PASS;
- Business Durability uses verified consecutive annual Revenue anchors;
- Owner Earnings requires same-period Revenue + SBC and positive verified FCF;
- existing SBC thresholds remain unchanged;
- exact repeat APPLY is idempotent;
- service-role-only;
- `auto_trade=false`;
- human execution only.

Canonical evidence live SQL acceptance: **16/16 PASS**.

## 4. Controlled evidence successfully canonicalized

### EOG

Controlled research receipt:

`45a398e2-ac66-4ea9-a204-79747787ae40`

Inserted:
- 1 Tier-A evidence record
- 2 canonical metric observations

Current owner-economics inputs:
- H1 2026 Revenue: **USD 15.541B**
- H1 2026 SBC: **USD 0.118B**
- verified positive LTM FCF already existed: **USD 6.653B**
- SBC / Revenue: approximately **0.7593%**

Result:
- Owner Earnings: **PASS**

### NFLX

Controlled research receipt:

`92d634fe-4281-44a4-8177-9d9c0364c8be`

Inserted:
- 2 Tier-A evidence records
- 5 canonical metric observations

Durability anchor:
- FY2023 Revenue: **USD 33.723297B**
- FY2024 Revenue: **USD 39.000966B**
- FY2025 Revenue: **USD 45.183036B**

Current owner-economics inputs:
- 9M 2026 Revenue: **USD 37.683871B**
- 9M 2026 SBC: **USD 0.405440B**
- verified positive Q3 2026 FCF already existed: **USD 2.883513B**
- SBC / Revenue: approximately **1.0759%**

Result:
- Business Durability: **PASS**
- Owner Earnings: **PASS**

All ChatGPT-originated production evidence writes used the existing controlled Research PREVIEW/APPLY gateway.

## 5. Current Quality Hardening state — acceptance invariants

These outcomes must be preserved unless new verified fundamental/valuation evidence legitimately changes them.

### ACN

Current hardening snapshot:

`HARD-QHR-ACN-20261026-7cf9191efa86`

- Business Durability: PASS
- Owner Earnings: PASS
- Value Trap: PASS
- Valuation Robustness: **REVIEW**
- Overall: **REVIEW**
- Valuation confidence: **0.9250**
- `quality_hardened=false`
- `investment_review_ready=false`

### EOG

Current hardening snapshot:

`HARD-QCE-EOG-20261026-8094977faaad`

- Business Durability: PASS
- Owner Earnings: PASS
- Value Trap: PASS
- Valuation Robustness: **FAIL**
- Overall: **FAIL**
- Valuation confidence: **0.7500**
- `quality_hardened=false`
- `investment_review_ready=false`

The previous evidence blocker was repaired. The remaining FAIL is a **real current robustness failure**, not missing evidence.

### NFLX

Current hardening snapshot:

`HARD-QCE-NFLX-20261026-2d4df8695276`

- Business Durability: PASS
- Owner Earnings: PASS
- Value Trap: PASS
- Valuation Robustness: **REVIEW**
- Overall: **REVIEW**
- Valuation confidence: **0.9250**
- `quality_hardened=false`
- `investment_review_ready=false`

NFLX improved from BLOCKED to REVIEW after canonical evidence was added. Do not force it to PASS.

## 6. Current price / mispricing context

The current daily-close compatibility bridge is working.

Last verified 2026-10-26 canonical prices used by hardening:
- ACN: **247.27**
- EOG: **163.685**
- NFLX: **63.895**

Current v2 mispricing:
- ACN
  - Bear upside ~ **-30.45%**
  - Base upside ~ **-5.91%**
  - PW upside ~ **-2.65%**
  - mispricing gate: insufficient
- EOG
  - Bear upside ~ **-73.39%**
  - Base upside ~ **+3.99%**
  - PW upside ~ **+3.58%**
  - mispricing gate: insufficient
- NFLX
  - Bear upside ~ **-39.99%**
  - Base upside ~ **+14.47%**
  - PW upside ~ **+19.65%**
  - active mispricing policy still does not produce a clean PASS because Base is below the 15% minimum.

Do not change these thresholds merely to promote a candidate.

## 7. Tests and safety verification completed

### Live SQL

- Valuation v2 production cutover: **14/14 PASS**, rollback verified
- Valuation Promotion Policy: **12/12 PASS**
- Quality Hardening Refresh Bridge after canonical evidence: **10/10 PASS**
- Quality Hardening Canonical Evidence: **16/16 PASS**

These are **live SQL regressions**, not GitHub CI.

### Idempotency

Canonical hardening repeat applies:
- EOG → `NOOP_ALREADY_REFRESHED`
- NFLX → `NOOP_ALREADY_REFRESHED`

An idempotency fingerprint bug was found during implementation because the prototype fingerprint included the prior hardening snapshot ID. It was corrected before release so final IDs depend on effective evidence/gate state instead.

### Access control

Canonical hardening preview/apply functions are service-role-only.  
Unauthorized apply returns:

`HUMAN_AUTHORIZATION_REQUIRED`

### Protected state

Verified unchanged across the canonical evidence/hardening writes:
- `portfolio_transactions`: 58
- `portfolio_source_positions`: 32
- `portfolio_live_holdings_rows_v1`: 15
- `portfolio_accounts`: 3
- `human_approval_packets`: 1
- `human_approval_events`: 0

No holdings, transactions, cash, accounting, approval, execution or trade mutation.

## 8. Problems / open blockers

### A. Decision Snapshot lineage is now the main MVP blocker

The upstream path is current through Quality Hardening, but downstream Decision/Ranking state has not yet been deliberately refreshed from the new v2 valuation + current hardening snapshots.

Last verified historical decision state before this handover work:
- ACN latest known decision snapshot: `DEC-ACN-REFRESH-20260911`
- EOG latest known decision snapshot: `DEC-EOG-REFRESH-20260911`
- those historical snapshots were linked to older valuation/mispricing/hardening state;
- NFLX did not have an equivalent current hardening-linked decision snapshot in the audited path.

**Recheck these facts live before implementing.** They are the diagnosis starting point, not permission to overwrite anything.

### B. Opportunity Ranking may therefore be stale

Ranking must not treat historical Decision Snapshots as current after the valuation/hardening cutover.

Expected invariant:
- EOG must not become an Immediate candidate while hardening is FAIL.
- NFLX must not become Immediate while hardening is REVIEW.
- ACN must not become Immediate while hardening is REVIEW / mispricing insufficient.

### C. Existing PINS ranking regression drift

`tests/decision/test_quality_durability_hardening_v1.sql` contains:

`QH-08 PINS production bucket`

Earlier baseline recheck returned **10/11 PASS** because the expected current PINS row was no longer present in `v_opportunity_ranking_current`.

Treat this as a **separate ranking-state/test-fixture reconciliation problem**.  
Do not modify Quality Hardening thresholds to make this regression pass.

### D. Shadow Decision Refresh remains non-authoritative

The legacy/automation document `docs/08_AUTO_DECISION_REFRESH_SHADOW.md` describes shadow evidence collection.

Do not promote shadow automation into production decision writes as a shortcut.

## 9. Exact Next Step for the new chat

Start **READ-ONLY**.

### Step 1 — Re-verify current authority

Verify:
- current GitHub `main` SHA;
- contract remains `FWIOS-CONTRACT-0.87.23`;
- current valuation + hardening snapshots for ACN/EOG/NFLX;
- `auto_trade=false`;
- current Decision Snapshot / Score / Ranking rows and lineage for ACN/EOG/NFLX/PINS.

### Step 2 — Diagnose the downstream dependency chain

Map:

```text
current valuation
  → current mispricing
  → current hardening
  → score / revision-chase inputs
  → Decision Snapshot
  → Opportunity Ranking
```

For each ACN/EOG/NFLX identify:
- latest Decision Snapshot ID;
- valuation run ID referenced;
- hardening snapshot ID referenced;
- mispricing snapshot ID referenced;
- score snapshot / revision snapshot dependencies;
- whether lineage edges point to current or historical upstream state;
- whether ranking currently includes/excludes the ticker and why.

### Step 3 — Decide whether a refresh bridge is needed

If downstream snapshots are stale, design the **minimum deterministic Decision / Ranking Refresh Bridge**.

Preferred behavior:
- preview first, non-mutating;
- select current authoritative valuation/mispricing/hardening;
- fail closed if hardening is not PASS;
- preserve existing revision/chase policy semantics;
- immutable new Decision Snapshot rather than rewriting historical rows;
- ranking consumes only current eligible decision state;
- deterministic/idempotent IDs;
- explicit lineage;
- service-role-only apply;
- explicit human authorization;
- zero portfolio/accounting/approval/execution mutations.

Do not create a new dashboard.

### Step 4 — Acceptance cases

At minimum prove:
1. preview is non-mutating;
2. current valuation/hardening lineage is selected;
3. EOG remains fail-closed;
4. NFLX remains review-only / non-Immediate;
5. ACN remains non-Immediate unless all existing gates genuinely pass;
6. no stale decision may displace a newer current decision;
7. exact repeat apply is idempotent;
8. service-role-only apply;
9. PINS ranking drift is diagnosed separately, not hidden;
10. holdings/transactions/cash/accounting/approval/execution remain unchanged.

### Step 5 — Only then apply/update docs

If the live diagnosis proves a safe bridge is needed:
- implement on a scoped feature branch;
- run live SQL regression;
- update `docs/CURRENT_STATUS.md`;
- update this handover or create a new one;
- bump the contract only if repository conventions require it for the material policy/runtime change;
- open/merge a PR after verification.

## 10. Do not do

- Do not redesign Valuation v2.
- Do not retune Quality Hardening thresholds.
- Do not relabel EOG FAIL or NFLX REVIEW merely to obtain ranking coverage.
- Do not directly use `decision_refresh_shadow_evidence` as authoritative production evidence.
- Do not rewrite historical immutable Decision/Hardening/Valuation snapshots.
- Do not mutate holdings, transactions, cash, cost basis, accounting, approvals or broker execution.
- Do not create a new Dashboard.
- Do not claim GitHub CI PASS when only SQL regressions ran.

## 11. Suggested opening instruction for the new chat

> Continue FWIOS MVP-1 from `docs/implementation/FWIOS_DECISION_RANKING_HANDOVER_20261027.md`. Start read-only. Verify latest main and live Supabase, then audit current Decision Snapshot / scoring / Opportunity Ranking lineage for ACN, EOG, NFLX and PINS. Do not change valuation or hardening thresholds. Preserve ACN REVIEW, EOG FAIL and NFLX REVIEW unless new verified evidence legitimately changes them. Diagnose stale downstream lineage first; only implement the minimum deterministic Decision/Ranking refresh bridge if the live audit proves it is needed.
