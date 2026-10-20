# Changelog

> Changelog entries record **merged GitHub changes and dated project evidence**, not independently verified current deployments. Use [Current Status](docs/CURRENT_STATUS.md) and fresh live-system inspection for operational assertions.

## 2026-10-20 — Contract alignment and documentation lifecycle

- Research readiness / fail-closed gates [PR #63](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/63) merged; current tracked contract is `FWIOS-CONTRACT-0.87.19` in `AGENTS.md` and `contracts/system-contract.yaml`.
- Documentation lifecycle, living status index, archived chat handovers and source-path compatibility links merged via [PR #64](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/64).
- Documentation cleanup reconciles the `VERSION` and README displays with the merged contract; preserves `VERSION` snapshot date as historical metadata, not proof of a new environment cutover.

## 2026-10-19 — Scanner separation and controlled research foundations

- Portfolio-independent Scanner read model and Dashboard decoupling merged through [PR #59](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/59) and [PR #60](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/60).
- Controlled ChatGPT research workflow and fail-closed ingestion gateway merged through [PR #61](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/61) and [PR #62](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/62).
- S&P 500 universe expansion is planned separately; prior 64-stock source snapshot is **not** full S&P 500 membership.

## 2026-10-13 to 2026-10-19 — Shared market-price infrastructure and Phase-1 portfolio integration

- Implementation records document merged PRs [#49–#52](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pulls?q=is%3Apr+is%3Amerged+49+50+51+52): provider quota, atomic reservations, single-flight scheduler and native USD market-data shadow. Review individual merged PR/commit for exact scope.
- Phase-1 implementation records document PRs #53–#57: live holdings/valuation reconciliation, Sheet read-only price cutover, crypto freshness correction, Portfolio Tracker cleanup and daily Performance snapshot repair. [Dated acceptance / handover](docs/implementation/FWIOS_PHASE1_HANDOVER_20261019.md).
- The existence of integration code and handover receipts **does not** establish autonomous U.S.-close E2E success on future trading sessions; verify current cron and Sheet/Supabase reconciliation.


## FWIOS-CONTRACT-0.87.0 — 2026-09-04

Initial standalone documentation contract synchronized to live **AI Data Foundation — Phase 0.87**.

Added:

- mandatory `AGENTS.md` execution contract;
- system architecture and source-of-truth rules;
- Focused Wealth-Building production scoring 30/30/25/15;
- fail-closed evidence, valuation, mispricing and Chase/FOMO gates;
- 17-model archetype valuation contract registry;
- Phase 0.87 production-route list;
- dependency-aware Blocked Resolution Orchestrator contract;
- Autonomous Sector Research Loop contract;
- change-management and regression policy;
- machine-readable `contracts/system-contract.yaml`;
- canonical strategy rules copy;
- `VERSION` handshake file.

Live-system handshake is expected to require foundation `0.87` before new autonomous sector execution.

## 2026-09-05 — Communication Services closeout recovery

- Reconciled completed research, history, universe, blockers and controller handoff.
- Added read-only no-promotion closeout checks and synthetic failure tests.
- Corrected operational documentation without changing valuation/scoring logic.
- Identified unresolved cache-aging and controller-completion defects; M1 hardening and M2–M4 remain open.

## 2026-09-11 — Auto Decision Refresh v1 shadow infrastructure

- Installed `pg_cron`, `pg_net` and `pgmq` for autonomous scheduling, HTTP invocation and queue/retry handling.
- Added private shadow run/job/evidence/provider-registry tables with database-level prohibition on authoritative writes from Shadow mode.
- Added `decision-refresh-worker-v1` with custom service token authentication, SEC filings/XBRL Company Facts collection, dormant dual-source price collection and dormant consensus collection.
- Added weekday post-US-close enqueue plus five-minute queue worker schedules.
- Validated first 27-candidate / 81-job shadow run: 27 SEC PASS, 54 provider-gated BLOCKED, 0 retry, 0 dead-letter after queue acknowledgement fix.
- Added 11/11 non-mutating automation infrastructure regression.
- Production cutover remains blocked until external market/consensus providers are configured, Tier-A validated and shadow-tested across multiple completed sessions.
- Human execution only; no auto-trading and no production decision mutation introduced.
