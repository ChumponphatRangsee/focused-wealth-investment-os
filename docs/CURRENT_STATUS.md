# FWIOS — Current Status / New-Chat Entry Point

> **Navigation index, not operational authority.** Updated **2026-10-27 Asia/Bangkok** after the Decision / Ranking Refresh Bridge v1 live cutover. GitHub `main` was verified at merge commit `81aba1e3a3ce62520c6b9da11838b1376b0ae531` (PR #85); active contract is `FWIOS-CONTRACT-0.87.23`. The Decision/Ranking bridge is live in Supabase and is being recorded on branch `fix/mvp1-decision-ranking-refresh-bridge`; re-check merge state before relying on repository parity. **Live operational truth overrides this dated index.**

## Mandatory read / execution order

1. Read [AGENTS.md](../AGENTS.md) and [system-contract.yaml](../contracts/system-contract.yaml); preserve human-execution-only and financial-accounting guardrails.
2. Read this index to find the **one** relevant feature plan, current PR, and any known blockers.
3. Check the current `main`, head/base of open PRs, and latest CI; inspect **actual live** Supabase/Sheets/cron/worker state whenever work would touch production.
4. Read the feature's implementation plan/runbook and current GitHub issue/PR before edits. Treat dated handover observations as historical evidence.
5. Make scoped changes in a separate PR; update this index after merging or accepted cutover. Reconcile any discrepancy before action.

## Repository / source precedence

- Repository: [focused-wealth-investment-os](https://github.com/ChumponphatRangsee/focused-wealth-investment-os), default branch: `main`.
- Latest verified GitHub `main` for this status update: `81aba1e3a3ce62520c6b9da11838b1376b0ae531` (PR #85 merge). Re-check on each new session.
- **Live operational truth > deployed source and current merged contracts > latest verified feature evidence > this dated index > archived handovers.**
- The active system contract controls execution safety. Historic architectural handover prose does **not** authorize a production cutover.

## Decision / Ranking Refresh Bridge v1 — LIVE / FAIL-CLOSED (2026-10-27)

- **Source handover:** [FWIOS MVP-1 Decision / Ranking Handover](implementation/FWIOS_DECISION_RANKING_HANDOVER_20261027.md) is now a historical input to the completed bridge audit.
- **Live migration:** `20261027033605 decision_ranking_refresh_bridge_v1`; policy `POL-DECISION-RANKING-REFRESH-BRIDGE-V1`.
- **Read-only diagnosis proved stale downstream lineage:** ACN/EOG Decision Score + Decision Snapshot still referenced September valuation/mispricing state; NFLX had current valuation/hardening but no canonical Portfolio Fit, score or Decision; PINS retained historical Decision/ranking state.
- **ACN refreshed Decision:** `DEC-DRB-ACN-b8eea53f1b52a486` → current valuation `VAL-PROD-ACN-ITSERV-V2-20261026` + current hardening `HARD-QHR-ACN-20261026-7cf9191efa86`; state remains **REVIEW - QUALITY HARDENING**. Input integrity is **BLOCKED - STALE PORTFOLIO FIT**.
- **EOG refreshed Decision:** `DEC-DRB-EOG-374bad5c8efc68a1` → current valuation `VAL-PROD-EOG-EP-V2-20261026` + current hardening `HARD-QCE-EOG-20261026-8094977faaad`; state remains **FAIL - QUALITY HARDENING**. Input integrity is **BLOCKED - STALE PORTFOLIO FIT**.
- **NFLX remains REVIEW and fail-closed:** no Decision was created because `PORTFOLIO_FIT_SNAPSHOT_MISSING`; current hardening remains `HARD-QCE-NFLX-20261026-2d4df8695276` = **REVIEW**.
- **PINS remains separate:** no PINS Decision rewrite was performed. Its current hardening is REVIEW while its Decision + Portfolio Fit lineage remains historical/stale; QH-08 ranking drift remains unresolved.
- **Portfolio Fit freshness exposed:** ACN/EOG/PINS latest fit snapshots reference `PORTFOLIO-M2-20260905-01`, while current portfolio state is `PORTFOLIO-MTM-20260924-01`. The bridge never promotes through this mismatch.
- **Ranking lifecycle drift exposed:** live `POL-OPPORTUNITY-RANKING-V2` is **RETIRED** after Opportunity Quality v2, despite older contract/status prose that still calls it active. The bridge intentionally does **not** reactivate it.
- **Ranking audit run:** `OPPRANK-DRB-800010edd38342f5`; ACN/EOG/PINS are auditable `EXCLUDED` rows and NFLX has no candidate row; `v_opportunity_ranking_current` remains **0 rows**. Downstream allocation/scenario/rebalance stays fail-closed.
- **Acceptance:** **24/24 PASS live SQL**; exact repeat Decision/ranking APPLY is `NOOP_ALREADY_REFRESHED`; current ACN/EOG hardening→Decision lineage edges exist.
- **Safety / unchanged:** valuation/hardening thresholds unchanged; scoring weights remain 30/30/25/15; protected portfolio/accounting/approval counts unchanged; `auto_trade=false`; no holdings, transactions, cash, approvals or execution mutation.
- **Next exact action:** refresh/reconcile **Portfolio Fit against the current portfolio batch first**, then explicitly reconcile whether the production capital path should use retired Opportunity Ranking v2 or Opportunity Quality v2. Do not reactivate Ranking v2 incidentally. After a canonical NFLX fit exists, verify its missing Revision/Chase/base-score chain before any Decision. Keep PINS ranking drift as an independent regression fix.

See [production receipt](implementation/FWIOS_DECISION_RANKING_REFRESH_BRIDGE_V1_20261027.md) and [regression SQL](../tests/decision/test_decision_ranking_refresh_bridge_v1.sql).

## Valuation input resolver / model-period audit — PR #77 MERGED (2026-10-26)

- **PR [#77](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/77) is MERGED to main.** It added the read-only valuation-contract/model-period audit and resolver foundation.
- **Live period audit:** 20 implemented models. Required-input period identity is RED for three routes: `IT_SERVICES_FCF_COMPOUNDER_V1` (ACN), `E&P_NORMALIZED_FCF_YIELD_V1` (EOG), and `STREAMING_FCF_DCF_V1` (NFLX). These encode FY/quarter identity inside required metric names and must not roll forward silently.
- **Version-governance findings from #77 were subsequently fixed by #78:** SEMIS now has one authoritative production version (1.1), and SAAS has canonical production version 1.1.
- **ACN resolver PREVIEW:** with FY2026 treated as closed on 2026-08-31, the current canonical set correctly blocks old FY2026 FCF guidance, pre-year-end FCF/net-cash/shares, and undefined generic `BOOK_TO_BILL` / `REVENUE_GROWTH_GUIDANCE_LC_MID` identities. Current Q3 margin metrics are diagnostics and are stale relative to the closed year.
- **Regression:** `tests/valuation/test_valuation_input_resolver_v1.sql` returned **7/7 PASS (READ-ONLY)** against live Supabase. No canonical metrics, model rows, version state, valuation runs or portfolio state were written.
- **Status:** superseded operationally by merged PR #78 and the ACN v2 APPLY/shadow receipt below. EOG/NFLX period-semantic follow-up is now completed through non-production shadow validation; see the live section below.

## Valuation period semantics v2 — PR #78 MERGED / LIVE (2026-10-26)

- **PR [#78](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/78) is MERGED to main.** Live Supabase migration `20261026101318 valuation_period_semantics_v2` was applied after a rollback dry-run.
- **Version authority fixed:** SEMIS 1.0 is retired and 1.1 is the sole production version. SAAS legacy `1.1-EXPERIMENTAL` is retired and canonical `1.1` is now the sole production version as an exact contract/policy/assumption clone. Historical valuation runs remain unchanged.
- **Period-aware semantics live:** generic `BOOK_TO_BILL`, `REVENUE_GROWTH_GUIDANCE_LC_MID` and `FREE_CASH_FLOW_GUIDANCE` definitions plus `METRIC_PERIOD_AWARE_V1` mappings are live. Four lineage-linked semantic alias observations cover ACN/EOG/NFLX without rewriting legacy observations.
- **ACN v2 contract:** `IT_SERVICES_FCF_COMPOUNDER_V1::2.0` is registered as `EXPERIMENTAL` with relative-period selectors and `production_read_cutover=false`. Reported FCF guidance values are no longer copied into v2 assumptions.
- **Verification:** migration dry-run PASS; post-apply valuation semantics regression **12/12 PASS**. ACN/EOG/NFLX Valuation Map values and valuation run IDs remained unchanged before/after migration.
- **ACN controlled APPLY completed:** payload fingerprint `451a19fcd56e8487161a173ed8ecc340`, receipt `df7bbf48-a141-429c-9b02-f488767eb3e2`; 2 Tier-A evidence rows + 7 canonical observations inserted. Repeating the same APPLY returned `NOOP_ALREADY_APPLIED`.
- **Canonical resolver now 7/7 required PASS** (plus 3/3 optional diagnostics PASS).
- **Immutable shadow v2 run created:** `VAL-SHADOW-ACN-ITSERV-V2-20261026`, `production_eligible=false`, 10/10 inputs PASS, 10 resolved metric-input lineage edges. Bear 171.9854, Base 232.6516, Bull 325.5685, PW 240.7143 (+3.28% vs v1). At price 249.415, shadow PW upside is about -3.49%.
- **Production boundary preserved:** Valuation Map still reads `VAL-SUPA-ACN-ITSERV-20260905` (v1 PW 233.0596473725). No production cutover and no trading action occurred.
- **Status:** superseded by the 2026-10-27 v2 production cutover section below; ACN v2 is now production.

## EOG + NFLX period-aware v2 — LIVE shadow validation (2026-10-26)

- **Live migration:** `20261026114938 eog_nflx_period_aware_v2`; Git migration filename is aligned to the live history version.
- **EOG v2:** `E&P_NORMALIZED_FCF_YIELD_V1::2.0` is `EXPERIMENTAL` with `production_read_cutover=false`. The period-aware resolver returns **8/8 required PASS** using current Q2/filing observations. Shadow run `VAL-SHADOW-EOG-EP-V2-20261026` is semantic-parity only and matches production Fair Value within rounding (PW 169.5415048).
- **NFLX v2:** `STREAMING_FCF_DCF_V1::2.0` is `EXPERIMENTAL` with `production_read_cutover=false`. New semantic `DILUTED_SHARES` separates the diluted weighted-average valuation denominator from economic period-end `SHARES_OUTSTANDING`.
- **NFLX Q3 controlled APPLY:** SEC Exhibit 99.1 payload fingerprint `1660dc6c3ba9a084e26194f41d89f48d`, receipt `d442ba44-c090-4d14-aec7-c7bc38c31c75`; 1 Tier-A evidence + 7 canonical observations inserted. Repeated APPLY returned `NOOP_ALREADY_APPLIED`.
- **NFLX resolver/shadow:** canonical resolver now **6/6 required PASS** (9/9 total selectors PASS). Shadow run `VAL-SHADOW-NFLX-STREAM-V2-20261026` gives Bear 38.3421, Base 73.1427, Bull 121.1811, PW 76.4521 versus v1 PW 78.9148 (-3.12%). At dashboard price 65.87, shadow PW upside is ~16.07%.
- **Verification:** EOG/NFLX shadow lineage edges are 8/9 respectively. Live regression: **10/10 PASS (SHADOW/NON-PRODUCTION)**.
- **Production boundary preserved:** EOG Dashboard still uses `VAL-EOG-20260904-P087`; NFLX still uses `VAL-NFLX-STREAM-20260911`. No model promotion, dashboard cutover, trading, or portfolio/accounting mutation occurred.
- **Status:** superseded by the 2026-10-27 v2 production cutover section below; EOG/NFLX v2 are now production.

## Valuation Promotion Policy v1 — LIVE / NON-MUTATING (2026-10-27)

- **Live migration:** `20261027015027 valuation_promotion_policy_v1`.
- **Policy:** `POL-VALUATION-PROMOTION-V1`, active deterministic readiness for validated shadow valuation runs.
- **Outputs:** only `AUTO_ELIGIBLE`, `MANUAL_REVIEW`, or `BLOCKED`.
- **AUTO_ELIGIBLE criteria:** 100% required inputs PASS; Tier-A VERIFIED conflict-free evidence; complete metric-input lineage; model regression PASS; singular current production version; explicit supersedes chain; valuation/router/schema gates PASS; same kernel family; maximum absolute Bear/Base/Bull/PW Fair Value delta <=15%.
- **Safety:** `auto_apply=false`, `human_cutover_required=true`, `portfolio_mutation=false`, `auto_trade=false`. The policy never promotes production by itself.
- **Historical pre-cutover result:** ACN/EOG/NFLX were all AUTO_ELIGIBLE and were subsequently promoted with explicit authorization on 2026-10-27.
- **Regression:** `FWIOS VALUATION PROMOTION POLICY V1: PASS (12/12, NON-MUTATING)`.
- **Access boundary:** preview function/readiness view are service-role-only; no public/anon/authenticated access.
- **Cutover completed:** this pre-cutover boundary statement is superseded by the 2026-10-27 production-cutover receipt. No trading, holdings, transaction, cash or accounting mutation occurred.
- **Simplified workflow:** `Evidence → Canonical Metrics → Resolver → Shadow Valuation → Promotion Policy`; AUTO_ELIGIBLE may be sent to one explicit service-role apply call, with rollback available if required.

## Valuation v2 production cutover — LIVE / ROLLBACK VERIFIED (2026-10-27)

- **Live apply/rollback migration:** `20261027020107 valuation_promotion_apply_rollback_v1`.
- **Controlled functions:** `fwios.apply_valuation_promotion_v1(shadow_run_id)` and `fwios.rollback_valuation_promotion_v1(production_run_id)`; service-role-only, human-authorized, no auto-trading.
- **Production authority:** ACN, EOG and NFLX v2 are now the sole `PRODUCTION` model versions with `production_read_cutover=true`. Their previous model versions are `RETIRED` but retained as rollback targets. Global authoritative production-version count remains 20.
- **ACN:** production run `VAL-PROD-ACN-ITSERV-V2-20261026`, model `IT_SERVICES_FCF_COMPOUNDER_V1::2.0`, PW Fair Value **240.7142520975**; rollback run `VAL-SUPA-ACN-ITSERV-20260905`.
- **EOG:** production run `VAL-PROD-EOG-EP-V2-20261026`, model `E&P_NORMALIZED_FCF_YIELD_V1::2.0`, PW Fair Value **169.5415048027**; rollback run `VAL-EOG-20260904-P087`.
- **NFLX:** production run `VAL-PROD-NFLX-STREAM-V2-20261026`, model `STREAMING_FCF_DCF_V1::2.0`, PW Fair Value **76.4521223650**; rollback run `VAL-NFLX-STREAM-20260911`.
- **Shadow immutability preserved:** all three original shadow runs remain `production_eligible=false`. Production runs are new immutable copies with exact Fair Value parity and copied canonical-input lineage (ACN 10, EOG 8, NFLX 9 edges).
- **Idempotency:** exact repeat promotion calls return `NOOP_ALREADY_PROMOTED`; no duplicate production runs are created.
- **Rollback verified:** all three rollback functions were executed inside a transaction and restored the prior Dashboard/model authority; the transaction was rolled back, leaving live production on v2. Result: `VALUATION_V2_ROLLBACK_DRY_RUN_PASS`.
- **Regression:** `FWIOS VALUATION V2 PRODUCTION CUTOVER: PASS (14/14, ROLLBACK-VERIFIED)`.
- **Existing Valuation Map verified:** Google Sheet already reflects v2 without manual edits — ACN 240.71, EOG 169.54, NFLX 76.45 Fair Value.
- **Downstream gates preserved:** `v_research_readiness_current_v1` resolves the new v2 runs and all three are `VALUATION_READY`, but currently remain blocked from investment-review-ready by **Quality / Durability Hardening**. Valuation cutover does not create a buy signal.
- **Safety:** promotion transaction asserted no changes to `portfolio_transactions`, `portfolio_source_positions`, `portfolio_live_holdings_rows_v1`, or `human_approval_packets`; `auto_trade=false`.
- **Next exact action:** stop adding valuation-cutover architecture. Continue MVP data reliability / Quality-Durability Hardening and refresh downstream decision lineage from the new v2 production valuations where warranted.

## MVP-1 scope correction — existing Valuation Map + Data Reliability, no new UI (2026-10-26)

- **Owner clarified goal:** do **not** build a separate dashboard/tab/report. Use the existing [Focused Wealth Dashboard / Valuation Map](https://docs.google.com/spreadsheets/d/17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8/edit) for display. MVP-1 measures **data capture completeness, correctness and freshness** for tracked stock prices, issuer financial facts, model inputs and revaluations. [Revised audit and acceptance checklist](implementation/FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md).
- **Price data (verified read-only):** last completed US session 2026-10-23; 64/64 accepted Twelve Data EOD stock observations each trading day Oct 19–23, all Tier-A PASS and URLs present. 13 independent Alpha Vantage overlap prices on Oct 23 differ 0–0.0261%; do **not** assert all 64 independently cross-checked.
- **Valuation Map parity:** existing Google Sheet's 28 valued rows match backend 28 rows for price date, price, Bear/Base/Bull/PW Fair Value and upside within displayed rounding. Valuation dates are Sep 4–11, despite Oct 23 price session.
- **Financial ingestion freshness — confirmed gap:** 453 `metric_observations` rows covering 28/64 tracked instruments; last database metric ingestion Sep 30 and newest stored source `reported_at` Sep 10. ACN's stored metrics last reported Jun 18 (issuer Q4 FY26 Oct 1), JPM Jul 14 (issuer Q3 Oct 13), NFLX Jul 16 (issuer Q3 Oct 20). Their latest source filings must be triaged and verified before claiming current Fair Value. The current ten active cron names contain no independently established scheduled canonical financial-metric ingest.
- **Immediate delivery item:** pilot source/evidence/period/unit audit and missing/latest earnings capture for ACN/JPM/NFLX, then manual verified `PREVIEW`; controlled `APPLY`/production revaluation **only with separately explicit authorization**, and validate the existing Valuation Map afterward. No new table, scheduler, spreadsheet UI, score/quality threshold or trading.
- **Previous MVP SQL report:** stays as a read-only diagnostic; not a UI to implement. Previously named "read-only user-facing report" next action is **superseded**.

## MVP-first owner reprioritization and read-only E2E audit — 2026-10-26

- **Active delivery priority: Phase 1 Working MVP**, not Research Attention #38, autonomous research scheduling, all-S&P500 expansion, portfolio rotation or backtesting. The [MVP-first working-slice plan and read-only audit](implementation/FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md) is the new scoped execution entrypoint.
- **Authorization scope:** roadmap/docs update and read-only E2E inspection; production schema/data, RLS, price jobs, scoring thresholds, policies, Google Sheets transactions and trading were **not modified**. New research APPLY and any production cutover require separate consent and regression acceptance.
- **Live Supabase read-only checks (2026-10-26):** 64 stocks in readiness view; 27 research-ready, 27 valuation-ready, 1 quality-hardened, 1 investment-review-ready. Scanner v1 scored/ranked 27 stocks; its score **does not mean investment-review-ready**. ACN readiness is READY but the independent old dashboard valuation map says `PRICE VERIFY`; preserve both meanings. ADBE's latest valuation and older hardening snapshot are not lineage-aligned, while PINS carries quality review and stale/conflicted legacy mispricing/decision signals. These are **acceptance/test cases**, not recommendations.
- **Next action:** the [MVP pilot SELECT](../queries/mvp_readonly_fair_value_status_v1.sql) has now returned 3/3 rows from existing views in live read-only inspection (ACN positive readiness but independent legacy-gate disagreement; ADBE lineage mismatch; PINS quality review). **Use the tested SQL only for investigation of freshness/lineage; do not build a new user-facing page.** Verify the existing Valuation Map data reliability and missing current financial inputs first, then fix one proven gap per separately reviewed PR. No runtime feature is yet deployed by this change.
- **Deferred:** Issue #38 remains OPEN but is **future backlog** until manual MVP and real resource constraints justify attention ranking/queues; Issue #39 remains cutover-gated. The proposed five-table attention schema is not approved. Scanner v2 and U1 are not automatically resumed.
- **Merge/deployment boundary:** check GitHub PR status for this roadmap/SELECT-only change; even a merge does **not** deploy a new end-user MVP report, adjust production gates or prove user-facing acceptance.

## Strategy documentation merge receipt — 2026-10-23

- [PR #70](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/70) **MERGED** into `main` at GitHub merge commit `f752f5c53441b0443e6d1660cfe31f6d733ea6f0`. The change is exclusively 4 Markdown files: an updated [master roadmap](00_SYSTEM_ROADMAP.md), new [Value / Entry / Rotation plan](implementation/VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md), README navigation and this index. At review, 50 local links checked with 0 broken.
- The strategy remains **PROPOSED**, not implemented/approved for production. It does **not** authorize ChatGPT scheduling, research APPLY automation, database writes, valuation policy changes, trading, scanner cutover or portfolio mutation. No CI check run was reported for PR #70; do not claim CI PASS.
- [Epic #31](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/31) checklist reconciled: #35/#36/#37 closed and foundation-complete; **production read cutover remains separately gated**. [Issue #38](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/38) now contains **design-only** attention/selection/promotion/demotion requirements and remains OPEN, with no implementation authorized. Issue #39 also remains OPEN.
- **Superseded next step (2026-10-26):** Phase 1 MVP read-only report acceptance and focused E2E blocker repair take precedence. Research-attention design #38 is deferred; Scanner v2 and U1 S&P 500 expansion remain separately paused.

## Workstreams (verified GitHub status versus older feature snapshots)

| Stream | GitHub state at index creation | Next source to read / validation |
| --- | --- | --- |
| **Portfolio native pricing / Phase 1** | PRs #49–#57 documented as merged by the 2026-10-19 receipt; current live pricing and autonomous E2E acceptance **not checked here** | [Phase-1 snapshot](implementation/FWIOS_PHASE1_HANDOVER_20261019.md), [acceptance](implementation/PHASE1_P3_P4_P5_ACCEPTANCE_20261017.md). Check current scheduled US-close outcomes first. |
| **Daily Performance Backend / historical backfill** | Dedicated plan/handover exists; **do not infer feature is deployed** without live verification | [Feature plan](implementation/PHASE1_DAILY_PERFORMANCE_BACKEND_HANDOVER_20261019.md); start schema/writer/reconciliation only after checking actual Supabase/Sheets state and relevant PRs. |
| **Focused Dashboard / S&P 500 expansion** | Scanner separation PR [#59](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/59) and cleanup PR [#60](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/60) merged. Prior 2026-10-19 evidence listed **64 stock instruments**, not full S&P 500; not independently checked today. | [Universe expansion plan](implementation/SP500_UNIVERSE_EXPANSION_PLAN_20261019.md); check membership/source-of-truth design and live row counts before U1 implementation. |
| **Controlled Research / Scanner v2** | PR [#61](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/61), [#62](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/62), and research-readiness PR [#63](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/63) are merged. PR #63 completed **21/21** readiness acceptance before merge; Scanner v2 is not part of this cleanup. | [Research workflow](implementation/CHATGPT_RESEARCH_WORKFLOW_V1.md), [controlled ingest](implementation/PR2_CONTROLLED_RESEARCH_INGEST_V1.md), [PR4 readiness](implementation/PR4_RESEARCH_READINESS_FAIL_CLOSED_V1.md). Next **scanner-specific** implementation step: Scanner v2 (not started by this documentation PR). The 2026-10-26 owner decision **defers Issue #38** until after Phase 1 MVP acceptance; do not conflate it with current delivery. U1/full S&P 500 expansion remains paused unless explicitly resumed. |
| **Value / Entry / Rotation strategy — future feature overlay** | Owner-approved MVP-first prioritization replaces D1–D6 as the **immediate** execution order; no runtime/production change. Future strategy choices still require explicit authorization. | [MVP-first working slice](implementation/FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md), [future strategy overlay](implementation/VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md). #38/#39 remain future gated tasks. |
| **External API inventory / security** | Audit PR [#48](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/48) **open**, not merged (checked 2026-10-20). | Review PR #48 before asserting audit closure or changing vendor credentials. |

## Non-negotiable guardrails

- `auto_trade=false`, human execution only. No autonomous order placement.
- Do not mutate Transactions, quantity, cost basis, realized P&L, cash, accounting formulas or portfolio holdings during documentation or scanner work.
- For Phase 1, `Investment Portfolio Tracker - Chumponphat` remains the accounting/transaction authority as recorded in the relevant Phase-1 implementation decisions. Do not create a duplicate transaction ledger.
- Scanner presentation remains portfolio-independent. Preserve quota-aware shared market-data infrastructure and avoid expensive all-constituent deep research.
- A successful GitHub merge **does not prove** production deployment or autonomous E2E success. Confirm receipts, timestamps and current backend state.

## Documentation hygiene — audited 2026-10-20

- Latest verified merged contract for this status update: `FWIOS-CONTRACT-0.87.23` in AGENTS, README, VERSION and system-contract YAML on `main` commit `51ab08328ce81af10c723482986b1bba0ed67bc3`. Re-check `main` on future sessions.
- [Documentation audit and classification](DOCUMENTATION_AUDIT_20261020.md): in-place legacy banners, historical evidence archives, files retained due to active dependencies and explicit deferred code retirement.
- The old Dashboard CSV function is still deployed as a rollback-only path in prior checked Supabase evidence; repository docs must not authorize deleting its deployed endpoint or shared valuation/thesis views.

## Legacy Dashboard — fail-closed runtime retired, physical undeploy pending (2026-10-23)

- [Execution receipt and live Edge verification](implementation/LEGACY_DASHBOARD_RETIREMENT_AUDIT_20261023.md). User confirmed no external clients / old Apps Script; private complete Google Sheet backup remains owner-only.
- Current Focused Wealth Dashboard retains only `S&P500 Scanner`, `Valuation Map`, hidden `_Scanner_Data` and `_Scanner_Config`; old `Dashboard`, `Thesis Tracker`, `Opportunity Quality`, `_Data` removed.
- Legacy access `GOOGLE_SHEET_IMPORTDATA` is **inactive**; scanner access `GOOGLE_SHEET_SCANNER_IMPORTDATA` remains **active**; `fwios.v_scanner_current_v1` returned **64 rows** after the runtime change.
- **Legacy CSV endpoint replaced with inert 410 tombstone:** deployed `dashboard-refresh-csv-v1` `ACTIVE v8`, `verify_jwt=true`, no database/portfolio reads. Five dashboard diagnostic probes already deploy inert 410 handlers with JWT verification. **All six slugs still exist on Supabase**.
- **Physical undeploy pending:** [Issue #68](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/68). Connected Supabase tools cannot undeploy functions; use a separate authorized platform action and verify inventory. Live HTTP invocation and full-trading-session E2E acceptance are not proven by a source/readback check.
- **Never drop:** shared `fwios.dashboard_refresh_access` table, `v_dashboard_valuation_map`, `v_thesis_tracking_current`, scanner Edge Function, or historical migrations.

## Documentation map

- **Current index:** this file, kept concise; update on meaningful workflow changes, not every Chat.
- **Contracts:** [AGENTS](../AGENTS.md) and [system contract](../contracts/system-contract.yaml).
- **Architecture:** [FWIOS v3](architecture/FWIOS_ARCHITECTURE_V3.md) (verify approved vs proposed decisions), [Master System Roadmap](00_SYSTEM_ROADMAP.md), and the **proposed, not implemented** [Value / Entry / Rotation strategy plan](implementation/VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md).
- **Active handoff details:** [Phase-1 dated snapshot](implementation/FWIOS_PHASE1_HANDOVER_20261019.md) and [Daily Performance feature handover](implementation/PHASE1_DAILY_PERFORMANCE_BACKEND_HANDOVER_20261019.md); these are **dated evidence**, not live state.
- **Historical handovers:** [archive index](archive/handovers/README.md); old paths remain short compatibility pointers only.
- **Rules for upkeep:** [Documentation lifecycle](DOCUMENTATION_LIFECYCLE.md).

## Quality Hardening Refresh Bridge v1 — LIVE / FAIL-CLOSED (2026-10-27)

- Live migration: `20261027023035 quality_hardening_refresh_bridge_v1`; policy `POL-QUALITY-HARDENING-REFRESH-V1`.
- The bridge repairs stale post-valuation-cutover hardening lineage from current production valuation + accepted canonical daily close without changing Quality Hardening thresholds.
- ACN = **REVIEW** on `VAL-PROD-ACN-ITSERV-V2-20261026`.
- EOG = **FAIL** on `VAL-PROD-EOG-EP-V2-20261026`.
- NFLX = **BLOCKED** on `VAL-PROD-NFLX-STREAM-V2-20261026`.
- All three remain `investment_review_ready=false`; exact repeat apply is `NOOP_ALREADY_REFRESHED`.
- bridge-specific live SQL acceptance: **10/10 PASS**. Baseline Quality Hardening recheck: **10/11 PASS** because the existing QH-08 PINS ranking fixture no longer has a current PINS row; the bridge does not write ranking tables.
- No portfolio/accounting/approval/execution/trading mutation; `auto_trade=false`, human execution only.
- Next: **superseded by the Canonical Evidence v1 section below**. Reconcile PINS ranking-test drift separately.

See [production receipt](implementation/FWIOS_QUALITY_HARDENING_REFRESH_BRIDGE_V1_20261027.md) and [regression SQL](../tests/decision/test_quality_hardening_refresh_bridge_v1.sql).

## Quality Hardening Canonical Evidence v1 — LIVE / CONTROLLED APPLY (2026-10-27)

- **Live migration:** `20261027031421 quality_hardening_canonical_evidence_v1`; policy `POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1`.
- EOG controlled research receipt `45a398e2-ac66-4ea9-a204-79747787ae40`: 1 Tier-A evidence + 2 canonical observations inserted through the controlled gateway. H1 2026 Revenue/SBC resolves SBC-to-Revenue at ~0.7593%; existing verified positive LTM FCF supplies the FCF check.
- NFLX controlled research receipt `92d634fe-4281-44a4-8177-9d9c0364c8be`: 2 Tier-A evidence + 5 canonical observations inserted. FY2023–FY2025 Revenue supplies the 3-year durability anchor; 9M 2026 Revenue/SBC resolves SBC-to-Revenue at ~1.0759%; existing verified positive Q3 FCF supplies the FCF check.
- **EOG current hardening:** `HARD-QCE-EOG-20261026-8094977faaad` → Business PASS / Owner Earnings PASS / Value Trap PASS / Robustness **FAIL** / Overall **FAIL**.
- **NFLX current hardening:** `HARD-QCE-NFLX-20261026-2d4df8695276` → Business PASS / Owner Earnings PASS / Value Trap PASS / Robustness **REVIEW** / Overall **REVIEW**.
- Both remain `quality_hardened=false` and `investment_review_ready=false`; no buy/trade signal was created.
- Canonical evidence/metric → hardening lineage is explicit; shadow evidence is not a production gate input.
- Deterministic fingerprint was corrected during validation so exact repeat applies are stable `NOOP_ALREADY_REFRESHED`.
- **Acceptance:** canonical evidence **16/16 PASS live SQL**; base Quality Hardening Refresh **10/10 PASS live SQL**. These are not GitHub CI.
- Protected portfolio/accounting/approval row counts were unchanged; `auto_trade=false`, human execution only.
- **Next exact action:** refresh downstream Decision / Ranking lineage from the now-current hardening snapshots without weakening EOG FAIL or NFLX REVIEW. Keep PINS ranking drift as a separate cleanup.

See [production receipt](implementation/FWIOS_QUALITY_HARDENING_CANONICAL_EVIDENCE_V1_20261027.md) and [regression SQL](../tests/decision/test_quality_hardening_canonical_evidence_v1.sql).

## On next material change

Record: date/timezone; checked GitHub commit and relevant PR state; verified or unverified live environment; completed scope; open blockers; exact next action; links to source evidence. Avoid numerical pricing or account-value snapshots in this index unless they are necessary and time-stamped.
