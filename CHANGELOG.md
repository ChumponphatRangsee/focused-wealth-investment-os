# Changelog

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
