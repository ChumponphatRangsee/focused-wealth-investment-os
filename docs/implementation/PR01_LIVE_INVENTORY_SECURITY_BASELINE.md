# PR 01 — Live Architecture / External API Inventory & Security Baseline

**Observed:** 2026-10-13, Asia/Bangkok  
**Implementation status:** PARTIAL — inventory and static CI guard implemented in this PR; credentials and production services **unchanged**.  
**Parent:** [FWIOS v3 Architecture](../architecture/FWIOS_ARCHITECTURE_V3.md) · [Prioritized Implementation Plan](API_QUOTA_IMPLEMENTATION_PLAN.md)  
**Machine-readable source registry:** [external_api_inventory.json](../../config/external_api_inventory.json)

## Current ownership vs proposed cutover

| Domain | CURRENT observed / active contract | TARGET after independent acceptance |
| --- | --- | --- |
| Portfolio decision/read state | Active FWIOS 0.87.17 says Supabase `portfolio_state.current_authority`; legacy read models active | Tracker alone owns executed trades and derived accounting; Supabase can consume authorized readonly summary |
| Market data and FX | Supabase market observations and legacy quote paths coexist with direct Google Sheet price sources | Supabase cached canonical price read API with unified quota |
| Scanner/research | Supabase + Focused Dashboard, legacy portfolio metrics still visible | Scanner/Research/Thesis only; no parallel transaction/accounting ledger |
| Github | contracts, migrations, Edge Function code, tests | keep same GitHub authority |

No ownership switch is approved or performed by this PR. Preserve `Transactions` and `Holdings` in the Tracker as-is. Keep legacy writers until after new read paths are reconciled.

## Deployed Edge Function inventory

Live Supabase Edge Function metadata (read-only, 2026-10-13):

| Deployed function | Version | verify_jwt | GitHub source on main | Boundary |
| --- | ---: | --- | --- | --- |
| `dashboard-refresh-csv-v1` | 7 | false | yes | sheet CSV refresh; app query-token check |
| `decision-refresh-worker-v1` | 14 | false | yes | research price/consensus; application authorization needs runtime verification |
| `decision-refresh-provider-validator-v1` | 4 | false | yes | price / provider validation |
| `decision-refresh-price-lag-retry-v1` | 2 | false | **no** | deployed-only; obtain deployed source and audit |
| `market-daily-close-worker-v1` | 3 | false | yes | stock close provider; application header-token check |
| `portfolio-mtm-refresh-v1` | 1 | false | yes | stocks/FX/crypto portfolio quotes; application header-token check |
| `dashboard-refresh-probe-v1` | 2 | true | **no** | deployed-only diagnostic |
| `dashboard-refresh-env-probe-v1` | 2 | true | **no** | deployed-only diagnostic |
| `dashboard-refresh-db-probe-v1` | 2 | true | **no** | deployed-only diagnostic |
| `dashboard-refresh-query-probe-v1` | 3 | true | **no** | deployed-only diagnostic |
| `dashboard-refresh-role-probe-v1` | 2 | true | **no** | deployed-only diagnostic |

**Interpretation:** `verify_jwt=false` alone does not prove unauthenticated access; several handlers implement application token gates. However **each** must have its authorization and invocation surface explicitly verified; the five deployed-only probes and price-lag retry are outside repository code review. Edge Function deployed binaries have not been source-compared with GitHub.

## Active cron schedule — metadata only

All 8 jobs below were active at inspection. Schedule strings are `cron.job.schedule`, not necessarily a user-local time zone; confirm scheduler timezone/cron SQL for execution windows.

| Job | Schedule | Potential API interaction |
| --- | --- | --- |
| fwios-shadow-decision-refresh-worker | `*/5 * * * *` | may run decision-refresh provider calls |
| fwios-provider-validator-v1 | `17 6 * * 1,3,5` | provider validation |
| fwios-market-daily-close-enqueue | `25 5 * * 1-5` | enqueues close jobs |
| fwios-market-daily-close-worker | `*/2 5-8 * * 1-5` | Twelve Data daily close |
| fwios-shadow-decision-refresh-enqueue | `10 6 * * 1-5` | enqueues decision jobs |
| fwios-thesis-health-refresh | `40 6 * * 1-5` | internal refresh; verify indirect fetch |
| fwios-opportunity-quality-refresh | `45 6 * * 1-5` | internal refresh; verify indirect fetch |
| fwios-portfolio-mtm-refresh | `*/15 * * * *` | portfolio market prices / CoinGecko + stocks / FX |

**Do not disable or rewrite active jobs** before verifying their invocation role, protected secret flow, quote/session semantics and rollback.

## Quota baseline

| Existing logical segment | Observed policy | Important limitation |
| --- | --- | --- |
| Alpha Vantage decision refresh | `daily_limit=25`; `price_budget=15`; `validator_budget=2`; `reserve_budget=3` | Separate policy/usage; daily limit and class budgets must be reconciled. Actual provider entitlement not verified. |
| Twelve Data daily close | `per_minute_budget=8`; `daily_budget=700`; `worker_batch=8` | Separate ledger also called from some portfolio MTM stock/FX paths; not proof it covers all Twelve Data calls. |
| CoinGecko | Portfolio MTM performs a batched HTTP price lookup | No equivalent centralized atomic reservation observed in GitHub MTM code for the CoinGecko call. |
| Decision refresh reservation | `fwios.reserve_decision_refresh_api_call_v1` | `UNLIMITED_OR_UNCONFIGURED` allows unconfigured group; PR 2/3 must migrate callers and change fail-open to deny. |
| Daily close reservation | `fwios.reserve_market_daily_close_api_call_v1` | Controls minute/day for this policy only; no common all-consumer plan/credit ledger. |

Usage tables and current records at inspection: `decision_refresh_api_usage` = 353; `market_daily_close_api_usage` = 3,232. Counts are baseline samples, not final cost reconciliation. Direct/provider calls in Sheets and deployed-only Functions still need further audit before claiming 100% coverage.

## Source inventory and static guard

Version-controlled functions under `supabase/functions/*/index.ts` are now declared in `config/external_api_inventory.json`. The static guard:

- rejects new/untracked Edge Function `index.ts` files;
- detects `fetch()` in a function wrongly marked `external_http=false`;
- checks explicit CoinGecko / Twelve Data / Alpha Vantage host references appear in the entry's provider list;
- requires quota mode, consumer, auth-boundary observation, and known debt finding;
- prevents claiming `VERIFIED_UNIFIED_QUOTA` without a verification reference;
- prevents storing `?token=` / `?api_key=` style URLs in the registry;
- runs via a credential-free GitHub Actions workflow on relevant PR/push paths.

**What this does not prove:** static inspection cannot prove runtime invocation authorization, source parity with deployed functions, application-level cache quality, provider billing credits, or reservation atomicity. A static PASS is *not* Quota Safe gate acceptance.

## Security + architectural findings

| Finding | Priority | Evidence and risk | Owner / next step |
| --- | --- | --- | --- |
| RISK-001 — Google Sheet token-bearing URL | **P0 / Security** | Focused Dashboard `_Data!V1` contains a live `dashboard-refresh-csv-v1` formula URL with a token query parameter. The token **is intentionally never copied into this repository**. | Design server-side/least-privilege sheet import; rotate/revoke old access token during coordinated cutover; confirm old URL fails and new refresh works. |
| RISK-002 — Portfolio MTM provider usage | **P0 / Quota** | `portfolio-mtm-refresh-v1` uses daily-close quota reservation for some stocks/FX, but the CoinGecko request path is not obviously behind shared reservation. Cron repeats every 15 min. | Inventory per external request including batch credit model; add unified CoinGecko reservation and cache-first single-flight in PR 2–4; only after tests. |
| RISK-003 — Fragmented quota enforcement | **P0 / Quota** | Decision refresh and daily close use different usage tables and reservation routines, provider validators contain mixed paths; fail-open policy when missing config. | PR 2/3 unified provider plan, credit ledger, global minute/day caps, fail-closed migration. |
| RISK-004 — Deployed-source inventory gaps | P0 / Security | One price-lag retry and five diagnostics active but not represented in the version-controlled five functions. | Compare deployed source and invocation auth; remove/disable probes only after ownership, use-case and dependency review. |
| RISK-005 — View security review | P1 / Security | `fwios.v_market_price_latest` and `fwios.v_portfolio_market_quote_current` use `security_invoker=true`. `fwios.v_decision_refresh_api_quota_today` has no reloption shown; schema exposure and grants still need checking. | Review effective access/RLS before exposing new shared price read endpoint. |
| RISK-006 — Price authority split | P1 / Portfolio | Tracker still gets quotes/FX from GOOGLEFINANCE/CoinGecko while Supabase has quote/observation layers. | Shadow compare first in PR 5/6; only remove direct provider paths after reconciliation. |

## Rotation runbook for RISK-001 (blocked on coordinated credential/access change)

1. Inventory every consumer of `dashboard-refresh-csv-v1` and current `fwios.dashboard_refresh_access` hash row, **without exporting the secret**.
2. Choose a compatible least-privilege integration. If Google Sheets `IMPORTDATA` cannot authenticate without URL tokens, migrate to a small authenticated Apps Script/server-side import with secret in a protected configuration, or change the dashboard read pattern.
3. Set up and test the replacement access path in a nonproduction or shadow surface. Check least-privilege data scope, request logging, rate limits and errors.
4. Switch the Sheet to replacement in a coordinated edit; verify correct data, freshness, formula continuity and normal refresh.
5. Revoke/deactivate the old token/access record (store hashes only); verify old token **fails** and no job still depends on it.
6. Record completion with secure operational evidence only; do not paste any token, full credential-bearing URL or private key in PR/CI/logs.
7. On failure, pause insecure old integration rather than reinstate a compromised URL. Restore data via verified secure fallback, label as stale as required.

No credential rotation, cron edits, Edge redeployment or database writes are made by the current PR.

## PR1 exit checklist and handoff

- [x] Snapshot current vs proposed authority/ownership (documentation).
- [x] GitHub-tracked Edge Function/provider inventory committed.
- [x] Active deployed Function metadata / cron name-and-schedule baseline captured.
- [x] Existing quota ledger and function gap classified.
- [x] Query-token exposure confirmed; no secret material placed in GitHub.
- [x] Static guard and regression tests authored, with CI workflow (CI execution must still be verified).
- [ ] Deployed-only Edge Function source/auth parity audited.
- [ ] Apps Script/direct Sheet API invocation inventory completed.
- [ ] Vendor plan quotas/credit pricing and reset windows independently verified.
- [ ] Secure replacement import tested and existing credential rotated/revoked.
- [ ] Reviewer confirms impact and sign-off for any production follow-up.

**Do not consider PR 1 security remediation done** while these boxes remain unchecked. PR 2 unified provider registry can be developed on a separate branch after code review, but no new production market-price cutover until PR 1 security and PR 2–4 quota gates pass.
