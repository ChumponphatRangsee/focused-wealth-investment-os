# DB-ARCH-2.0 — Phased Implementation & Acceptance Plan
**STATUS: PLANNED / NOT DEPLOYED.**
**Authorization state (updated 2026-11-10):** Provider Strategy v1 **APPROVED**, architecture design **COMPLETED**. User explicitly authorized starting the **SEC-first Research MVP isolated code-only pilot** on 2026-11-10. Production database migrations, new secrets, Edge Worker/Cron, paid-provider subscription, production rollout, broader control-plane implementation and 17-table activation are **NOT APPROVED**. This separate pilot lives under `research/sec_first_mvp/` with contract `contracts/sec-first-research-mvp-v0.yaml` and is **NOT_DEPLOYED**.

This is a **proposal for later separate implementation authorization**, not instructions to execute now.

## 0. Explicit safety preflight (required before every future implementation PR)

- Re-read GitHub `main`, `contracts/system-contract.yaml`, `docs/CURRENT_STATUS.md`, `docs/PRICE_PIPELINE.md`, `docs/database/CURRENT.yaml`, `docs/database/current/MANIFEST.yaml`; verify live Supabase schema, triggers, functions, grants, Crons, Edge versions and migration head read-only.
- Confirm current price-service authority and no portfolio backend resurrection; `fwios.market_observations` append-only, `fwios_quota.api_call_ledger` intact, `auto_trade=false`, no Google Sheet accounting mutation.
- Confirm actual account provider entitlements, use/redistribution rights, endpoint limits, terms and licensing, secret storage, local budget and cost approval.
- Ensure natural Crypto #20 and Twelve #17→#18 E2E acceptance remain separate from new research tests. Issue #106 is not closed merely because this design is merged.
- Define rollback and data-exposure impact. Any DDL must use a guarded, reviewed migration in its *own* later PR; do not alter current DB documents before a deployed, verified promotion.

## 1. Execution gates, dependency ordering and deliverables

| Gate | Scope | Required outcome | Can start now? |
|---|---|---|---|
| **D0 — Strategy authorization** | Decide sources, roles, cost ceiling and exclusions | **APPROVED 2026-11-09**; Alpha excluded | Complete |
| **D1 — Architecture documentation** | Registry, data contracts, lineage, security, limits, rollout plan, private schema design | Proposed `DB-ARCH-2.0`, reviewable PR and CI | **Authorized: design/documentation only** |
| **I0 — Implementation permission** | Approve *specific* MVP objects/credentials/budgets/worker scope | **SEC-first offline Python prototype only** authorized on 2026-11-10; no live creds, new schemas or deploy | **ONLY isolated offline SEC code** |
| **I1 — Control-plane isolated test** | Provider and capability fixtures, route-policy schema, account budget/idempotency SQL, no live production route | Isolated schema/tests and Postgres concurrency proof, grants and failure cases | **NO** |
| **I2 — SEC-first research pilot** | 3–5 issuers/securities with original SEC facts/filings and source lineage; optional Massive entitlement sample only if authorized | **Offline parser + synthetic unit fixtures authorized and in progress**. Authentic 3–5-company probe, proven first-public availability, persistent data and any live deployment still require separate review | **Offline code only** |
| **I3 — Bulk EOD + index membership pilot** | Current licensed constituents then date-valid historical membership, grouped EOD after NY midnight `adjusted=false` | Per-bar trace, share-class mapping, completeness and lossless source link; no survivor bias | **NO** |
| **I4 — Optional paid fundamentals/news** | Massive Financials & Ratios / news only if justified and separately approved; validate provider semantics, coverage and license | Confidence + expense evidence, missing data rate, point-in-time gate | **NO** |
| **I5 — Fallback + governed research reads** | Capability-specific failover policies, audit, queue/backpressure, read-only screening/evidence API | Replay/idempotency and negative-case evidence; no price or portfolio writes | **NO** |
| **I6 — Production deployment/promotion** | Guarded migrations, services, ACLs, schedules if explicitly approved | Production postflight, rollback validation, `current` docs rebuilt from live state | **NO** |

**Implementation update (2026-11-10):** The first offline SEC code pilot is now authorized and separately contracted. This does not authorize 17 table migrations, actual private research schema provisioning, new Edge functions, paid providers or Production deployment. The pilot deliberately marks `historical_backtest_certified=false` and `first_public_at=null` where independently proven timing is unavailable. No automated SEC fetch occurs in CI.

**No automatic stage progression.** Approval of a design is **not** approval of I0–I6, and approval of one implementation phase is not approval of a new provider subscription or production promotion.

## 2. Minimal first implementation scope to seek approval for (proposal)

Prefer **SEC-first, no-new-monthly-cost evidence pilot** with an isolated harness before broad bulk providers. Proposed pilot picks 3–5 diverse issuers, verifies CIK/ticker and accessions, stores append-only typed facts and intentionally tests restatements, delayed filings and missing custom-tag data. No fair-value number or buy/sell signal is generated in that pilot.

Only after the pilot confirms data quality should a guarded Provider Control Plane be proposed. Use a minimal subset of the proposed 17 tables; do **not** automatically implement all 17. If the scope cannot fit securely within existing production limits, draft a separate infrastructure/cost decision before proceeding.

**User decisions reserved for later:** approve exact MVP tables, target shares/issuers, any new Edge workers, whether/how to provision Massive Basic for non-production tests, whether to buy the $29/month add-on, legal rights for S&P 500 membership, and any future Cron cadence.

## 3. Test and acceptance matrix (future)

| ID | Test / negative case | Required result |
|---|---|---|
| C1 | Existing `fwios` table/rows, `fwios_quota`, Crons and Edge inventory before/after | Byte/identity-equivalent expected protected state; no mutation |
| C2 | Service access to a private `fwios_provider` schema | Only explicitly granted server role can access; `anon`/`authenticated` denied |
| C3 | Two concurrent duplicate provider requests | One durable reservation; no double dispatch; same fingerprint |
| C4 | Budget at exactly cap / provider account quota unknown | Cap blocks dispatch; unknown entitlement blocked |
| C5 | Timeout after provider dispatch | Mark `UNKNOWN`, conservatively consume quota; no manufactured retry |
| C6 | Cancellation of undispatched reservation | Canceled exactly once; only demonstrably never sent slots freed |
| C7 | Massive Basic EOD before NY midnight | Block; do not claim current-session EOD from free tier |
| C8 | Massive `adjusted=true` or omitted adjustment | Reject for `UNADJUSTED REGULAR_CLOSE` contract |
| C9 | Wrong trading session / mixed dates / holiday | Fail closed, no backdating or partial batch certified |
| C10 | Missing 1 of 4 required held EOD observations | No change to price-service atomic 4/4 Sheet readback behavior |
| C11 | Current S&P 500 members used on earlier simulated date | Historical membership backtest blocked; `CURRENT_UNIVERSE_ONLY` explicit |
| C12 | Duplicate ticker/reused symbol or renamed share class | Dated alias resolution, no false issuer/security merge |
| C13 | Original and restated filings conflict | Both versions persisted; as-of selection honors first-public source |
| C14 | 2026 vendor metric projected into 2024 period | Historical point-in-time read blocked if not knowable in 2024 |
| C15 | SEC 10-K/10-Q amended accession | Original and amendment provenance visible, immutable |
| C16 | Vendor statement missing concept/unit/period | `QUARANTINED` or `BLOCKED`, no silent zero-filled metric |
| C17 | News article first seen later than published timestamp | Historical discovery uses `first_seen_at`, no backdated catalyst |
| C18 | Restricted content redistribution / unverified personal license | No public display or raw content retention beyond rights |
| C19 | Incomplete research batch / duplicate fetch | Explicit incomplete count + replay-aware dedup; no false 500/500 PASS |
| C20 | Attempt to pass Research EOD bar into `fwios.market_observations` | Denied without independently authorized bridge/price contract |
| C21 | Simulated provider outage + eligible secondary | Per-capability route and license gates; no silent substitution |
| C22 | Retroactive correction of accepted fact | Append new version, retain original and edge lineage |
| C23 | Disabled/new provider has token missing | Fail closed and do not attempt external network |
| C24 | Supplier content raw URL embeds API key | Sanitized before log/store; keys never in GitHub or Sheet |
| C25 | Source retention job touches price canonical history | Hard fail; `fwios.market_observations` cannot age-prune |
| C26 | Any workflow proposes trade / accounting write | Prohibited, `auto_trade=false`, no account mutation |

Every future result must distinguish unit/fixture PASS from **real live authenticated provider and Sheet readback PASS**. No implementation task can claim Production E2E accepted merely from CI.

## 4. CI and rollout strategy (future)

- Use dedicated offline fixture-based tests for input adapters with adversarial timestamps, split adjustment, missing bars and provider quota errors.
- Use isolated PostgreSQL in CI to test atomic reservations, row-level permissions, append-only guards, FK, unique and interval integrity, replay and race conditions. **No database migration is written or applied now.**
- For any approved authenticated provider probe, use a named low-budget, limited-ticker request scope and a secure key; never ask to paste secrets into chat or GitHub.
- For future production activation, feature flags default `DISABLED` and allowlist exact provider+capability+symbols; start with one source and sample symbols. Do not change price worker path or research universe and Sheet scope in the same rollout.
- Metrics for future operators: reserved/used credits, forecast USD spend, 429/503, retry/UNKNOWN, 95p lag, source completeness, lineage missing rate, validation rejection, data license rejects, raw storage and per-provider source lag.
- Rollback should disable the new route/schedule, retain append-only audit and raw evidence, and leave historical prices intact; do **not** hard-delete data or roll back the existing price Crons to old Alpha behavior.
- `docs/database/CURRENT.yaml` promotion requires documented implementation authorization, verified live deployment, regression/postflight PASS and archived DB-ARCH-1.0 before updating current docs. No planned file is authoritative for live queries before that.

## 5. Forecast and budget guardrails (planning only)

| Workload | Research estimate | Hard gating |
|---|---|---|
| Massive grouped EOD | ~22 requests/month for ~22 sessions; initial two-year bootstrap ~500 calls, 100-minute theoretical floor at 5/min | Free tier entitlement, prior NY-midnight availability, vendor data/license and rate headers |
| Twelve focused at current four holdings | ~4 EOD symbol credits/session, ~88/month at 22 sessions | Existing deployed worker and 15-symbol live cap remain unchanged |
| Twelve hypothetical 50 research symbols | ~1,100 symbol credits/month at 22 sessions; minute budget dominates | Requires new approved service/policy; does not enlarge live price worker |
| Massive financial data | Four endpoint-family requests is a **minimum before pagination** | $29/mo subscription requires separate approval; actual coverage/credit and point-in-time validation |
| SEC filings and Company Facts | Low call cost but potentially large nightly archives and processing | Fair access, User-Agent, data versioning, storage and source completeness |
| CoinGecko | Existing current cadence unchanged | No extra quote polling under this approval |
| Frankfurter | Existing current cadence unchanged | No blending-source or other FX mode change under this approval |

**Approved additional spend now: $0.** The Strategy's approximately $29/month scenario is an estimate for an optional later activation, **not** an approved bill or prerequisite for documentation.

## 6. Closeout conditions for Architecture Design (D1)

- All planned `DB-ARCH-2.0` docs present and explicitly `PLANNED/NOT_DEPLOYED`, current architecture pointer unchanged.
- User's Strategy approval accurately recorded, with earlier DRAFT review retained as dated historical evidence.
- Correct provider mapping, rate/fee assumptions, evidence provenance, 500-universe PIT risk, security, row/field contracts, failure cases, cost and phased gates.
- Price-only CI PASS on documentation PR; verify only docs and planned/ files changed.
- No API or worker manually invoked and Issue #106 remains open.
- **Implementation authorization remains pending a separate user decision**. This is the formal D1 exit, not an instruction to start I0.
