> **ARCHIVED HANDOVER — HISTORY ONLY (archived 2026-10-20).** Describes the state as documented on its original date; **not** an instruction to execute today. Start at [Current Status](../../../CURRENT_STATUS.md) and verify live services before further work.

# FWIOS v3 — PR5 Handover to Next Chat

**As of:** 2026-10-15 (Asia/Bangkok)  
**Objective:** Finish the USD-only canonical market-price service, safely progress native USD crypto ingestion, and prepare PR6 shadow consumer without affecting legacy portfolio accounting.  
**Repository:** `ChumponphatRangsee/focused-wealth-investment-os`  
**Current PR:** [#52](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/52)  
**Current branch:** `feat/pr5-native-usd-price-shadow`  
**Stack:** [PR2 #49](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/49) → [PR3 #50](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/50) → [PR4 #51](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/51) → PR5 #52. **All four still DRAFT/UNMERGED at last inspection.**  
**Supabase project:** `ysjbmeukwbfnxnwqchuq` (production-as-test: protect existing live workloads).

## 1. Owner decision / architecture invariant

- Canonical **asset market prices** for all supported stocks and cryptos must be **native USD**, not only the PR4 Canary test set. API returns `price_usd`, `currency=USD`, source observation ID, provider, session time, freshness, and explicit eligibility. No amount derived from a stale FX quote can be presented as a valid native USD price.
- `USDTHB` is a separate **FX reference** (THB per 1 USD), not an asset market price. Google Sheets Portfolio Tracker may calculate THB presentation/portfolio values from USD price × validated USDTHB. **Google Sheets Tracker owns executed transactions, quantities, cost basis and P&L** under the planned post-cutover model.
- Historical THB-denominated raw observations are retained **truthfully** for lineage/compatibility/rollback; do not rewrite raw `THB` records and merely relabel them `USD`. Do not change recorded THB trade amounts, cost basis, or cash.
- **No new live PR4 provider dispatch, auto-trading, background Google Sheets price sync, portfolio-ledger writes or accounting cutover** without explicit validated gates.

## 2. Completed PR5 changes (verified on 2026-10-15)

| Task | Artifact | Status |
| --- | --- | --- |
| USD-only target spec | `docs/architecture/FWIOS_ARCHITECTURE_V3.md`, `docs/implementation/API_QUOTA_IMPLEMENTATION_PLAN.md`, `contracts/system-contract.yaml` (on upstream PR4 branch) | Documented; not production cutover |
| Additive native-USD read RPC | `migrations/20261015_pr5_native_usd_read_shadow_v1.sql` | **Applied** to Supabase as `fwios.pr5_native_usd_read_shadow_v1`; SQL function is `fwios.pr5_native_usd_price_shadow_v1(text)` |
| Read-only shadow consumer | `supabase/functions/market-price-usd-shadow-v1/index.ts` | **Deployed ACTIVE v1**, `verify_jwt=true`; new independent Edge endpoint |
| Crypto native USD provider adapter | `supabase/functions/_shared/pr5_coingecko_usd_adapter.ts` | Pure parse/validate/request-URL builder; **not wired to HTTP dispatch**, no live CoinGecko USD request |
| Adapter test source | `tests/pr5_coingecko_native_usd_adapter_test.ts` | 8 synthetic Deno tests **PASS / 0 FAIL in GitHub Actions on 2026-10-15** |
| All-instrument shadow audit | `queries/pr5_native_usd_shadow_all.sql` | Executed successfully; exactly **70 asset rows** |
| Native USD original-data coverage | `queries/pr5_usd_native_coverage.sql` (in upstream PR4 branch) | SQL audited 70 instruments |
| Operational runbook | `docs/implementation/PR5_NATIVE_USD_SHADOW_RUNBOOK_20261015.md` | Deployed receipts, rollback, limits documented |
| Stack tracking | Draft PR #52 based on `feat/pr4-cache-singleflight-priority` | Open, unmerged |

**Observed, not assumed:** `fwios.pr5_native_usd_price_shadow_v1` is `STABLE SECURITY INVOKER`, selectively reads `fwios.market_observations`, requires canonical identity and true `USD`, rejects QA/unsupported/ambiguous, never invokes an external provider, and exposes `shadow_only=true`, `read_only=true`, `valuation_eligible=false`, `accounting_eligible=false`, `trading_eligible=false`, `new_provider_calls=0`, `new_quota_reservations=0`.

**Permissions checked:** EXECUTE for `anon=false`, `authenticated=false`, `service_role=true`. Edge gateway JWT verification remains ON. Don't disable `verify_jwt`; merely decoding JWT in Edge is not signature verification.

## 3. Verification receipts

SQL read executed against the actual project on October 15, 2026:

| Current active canonical category | PR5 USD response | Count |
| --- | --- | ---: |
| Stock | `LAST_CLOSE` native USD | 63 |
| Stock | `MISSING` | 1: CRWD |
| Crypto | `MISSING` | 6: BTC, DOGE, ETH, HBAR, SOL, XRP |
| **Total** | All 70 examined | **70** |

- Zero returned asset quotes with incorrect non-USD unit or mistakenly `valuation_eligible=true`.
- `LAST_CLOSE` does **NOT** imply live market price; inspect observation time, session and provider.
- Test with `SELECT fwios.pr5_native_usd_price_shadow_v1('NVDA');`, `('BTC')`, `('CRWD')`; or use `queries/pr5_native_usd_shadow_all.sql`. Run these in authenticated Supabase SQL Editor.
- New Edge: `https://ysjbmeukwbfnxnwqchuq.supabase.co/functions/v1/market-price-usd-shadow-v1?asset=NVDA`; **authenticated HTTP E2E remains UNVERIFIED** (project had `auth.users=0`, no client JWT; `SUPABASE_DB_URL` present/functional inside Edge also not proven by HTTP).
- Status checks: **8** active legacy cron jobs, **0** PR4 in-flight refreshes, **0** provider registry entries with PR4 migration state `ACTIVE`, **0** Supabase Auth users. These are factual snapshots, not an assertion that legacy workers stop using provider APIs.
- No changes made to live `portfolio-mtm-refresh-v1`, old Canary, portfolio transactions/holdings, Google Sheets data/formulas or scheduler.
- The older PR4 Canary BTC/USD is **FX-derived and may be STALE**; it must not be mistaken for native USD. This PR5 RPC correctly returns BTC `MISSING`.

## 4. Main blocker: CoinGecko shared quota

Verified CoinGecko PR4 registry fields:
- `active=false`
- `readiness_status=DISABLED`
- `migration_state=SHADOW_ONLY`
- `plan_id=UNVERIFIED`
- `entitlement_status=UNVERIFIED`
- Endpoint credit cost, reset windows and shared-account budget are unverified.

**Existing live** `portfolio-mtm-refresh-v1` still uses `api.coingecko.com/api/v3/simple/price?ids=...&vs_currencies=thb&include_last_updated_at=true`, writes THB-native crypto snapshots, and can use legacy FX fallback. These vendor requests must be inventoried as competing consumers before permitting new USD polling; disabling the PR4 provider config does not automatically disable a separate legacy code path. Changing the live worker's `vs_currencies` in place could break valuation consumers.

CRWD has a canonical active instrument but no PASS native USD observation in `fwios.market_observations`; price seen through GOOGLEFINANCE in the Tracker is not automatically approved provenance for canonical Supabase market data.

## 5. Remaining work, suggested exact order

1. **Verify CoinGecko real plan and quota end-to-end:** endpoint permission, minute/day/reset/credit costs, shared provider account and existing legacy worker requests; confirm PR3 Reservation → Dispatch → Finalize controls (including retries, 429, failure credits). Continue fail-closed if any critical entitlement fact cannot be confirmed.
2. **COMPLETE: all eight CoinGecko pure adapter unit tests passed** in Deno 2.x GitHub Actions run #38720690779 (2026-10-15). This is not a live provider, DB or authenticated Edge test. Add additional tests only for discovered bugs.
3. **Integrate USD six-crypto batch adapter** with protected PR4 cache/single-flight/priority, not an independent raw `fetch` loop, only after verified quota. Store genuine USD source observations (price, instrument ID, provider, timestamp, session, provenance) in the canonical market observation path, keeping historical THB facts.
4. **Resolve CRWD verified USD source** under the same provider policy; do not invent quote or copy a sheet value as trusted market data without source verification.
5. **Re-run 70-asset USD audit and freshness gates:** 70 USD-native, or explicit `MISSING`/blocked, no silent currency conversions, cross-session stock rules, crypto TTL, proof of no double-spend.
6. **Perform Edge HTTP E2E** with authorized FWIOS Auth user only (do not generate or expose service-role credentials in browser); check Edge DB connection and gateway behavior. Existing JWT restriction stays enforced.
7. **PR6/PR7 only after PR5 gates:** add Google Sheets Tracker import-only `_Market_Data` shadow USD price columns and separate validated FX; reconcile Best, Loan Money, Mom, ALL at same quote+FX set; only after sign-off change Price Data read formulas. Never edit Transactions, Holdings accounting formulas or P&L prematurely.
8. **Stacked PR release:** review #49 → #50 → #51 → #52; do not merge solely because Supabase additive migrations were applied. Confirm deployment/code drift and rollback before each merge.

## 6. Practical next-chat instructions

Read these GitHub artifacts first:
- [PR5 #52](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/52)
- [PR5 operational runbook](../../../implementation/PR5_NATIVE_USD_SHADOW_RUNBOOK_20261015.md)
- [Native USD-only RPC migration](../../../../migrations/20261015_pr5_native_usd_read_shadow_v1.sql)
- [Protected USD Edge](../../../../supabase/functions/market-price-usd-shadow-v1/index.ts)
- [CoinGecko USD adapter](../../../../supabase/functions/_shared/pr5_coingecko_usd_adapter.ts)
- [Adapter tests](../../../../tests/pr5_coingecko_native_usd_adapter_test.ts)
- [70-asset SQL audit](../../../../queries/pr5_native_usd_shadow_all.sql)
- [Parent PR4 #51](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/51)
- [USD-only architecture](../../../architecture/FWIOS_ARCHITECTURE_V3.md)

**New-chat kickoff prompt:**

> Continue FWIOS v3 PR5 from `docs/implementation/PR5_HANDOVER_TO_NEXT_CHAT_20261015.md` on branch `feat/pr5-native-usd-price-shadow` / Draft PR #52. Use GitHub and Supabase connected tools to verify live state before any changes. The USD-only read-only shadow is deployed and 70-asset SQL audit yielded 63 LAST_CLOSE native USD stocks + 7 MISSING (all six cryptos and CRWD). First tackle actual CoinGecko quota/legacy shared account compatibility and execute existing USD adapter tests. Only integrate true native USD ingestion through protected PR3/PR4 quota and single-flight after verified vendor entitlements. Do not overwrite THB historical observations, enable new dispatch prematurely, merge PRs, create Google Sheets sync, or alter trade/accounting/portfolio state. Document tests and update PR #52 with exact results.

## 7. Rollback and safety

The newly deployed `market-price-usd-shadow-v1` is read-only and has no production consumers. If necessary, deactivate only this Edge function; leave migration and historical observation data intact (private EXECUTE grants). No need to change existing Cron, provider policy or Google Sheets. Do not expose service-role or `SUPABASE_DB_URL` secrets in GitHub or Sheets.

**Important label:** PR5 is *implemented for native-USD shadow read*, **not completed for native USD ingestion or production portfolio usage**.


## 8. Continuation verified 2026-10-15 — latest receipts (supersedes earlier NOT RUN wording)

- **Code commit:** `934d8f7` adds an offline Deno CI workflow; [run #38720690779](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/actions/runs/38720690779) is **SUCCESS: eight tests passed, zero failed**. All eight existing synthetic test cases ran; there was no vendor dispatch or API credit use.
- Supabase still **63 LAST_CLOSE native USD stocks + 7 MISSING**. RPC grants `anon=false / authenticated=false / service_role=true`, new Edge ACTIVE v1 `verify_jwt=true`; active Cron 8, in-flight PR4 0, Auth users 0.
- **Quota policy READ proof:** `resolve_provider_quota_policy_v1('COINGECKO','CRYPTO_SPOT','/simple/price')` gives `allowed=false`, `dispatch_allowed=false`, `reason=PROVIDER_DISABLED`, `endpoint_credit_cost=null`, `vendor_reset_status=UNVERIFIED`. Actual FWIOS CoinGecko account and vendor credits remain **UNVERIFIED**.
- **Legacy public path clarified:** `fwios-portfolio-mtm-refresh` scheduled every 15 minutes; legacy `portfolio-mtm-refresh-v1` calls CoinGecko public URL `api.coingecko.com` for THB without a CoinGecko key and without PR3 unified quota. This is an IP/public rate-limit exposure, **not proof of a shared paid/Demo account**; reconcile both before enabling new provider dispatch.
- **CRWD forensic check:** zero raw `fwios.market_observations` rows for canonical CRWD at inspection, so do not invent a native USD quote; approved upstream source acquisition needed.
- Authenticated Edge HTTP E2E is **still pending**, not simulated with service-role keys.
- **New documents:** [updated PR5 runbook](../../../implementation/PR5_NATIVE_USD_SHADOW_RUNBOOK_20261015.md) includes tests and live evidence; [PR6 gated shadow-sync plan](../../../implementation/PR6_PORTFOLIO_TRACKER_SHADOW_SYNC_GATED_PLAN.md) is design-only. Google Sheets, Cron, ledger/accounting, historical THB quotes and all provider flags unchanged. PR #49–52 remain Draft; no merge.


## 9. MVP-first continuation — 2026-10-16 (current handover)

Owner changed Phase 1 strategy from infrastructure-first to feature-first. Keep existing PR2–PR4 foundations, but defer further enterprise-scale hardening unless required by a working feature.

### Current live result

- CoinGecko crypto: legacy portfolio worker now requests `usd,thb` in the same batch call. Existing THB snapshots remain; native USD is additionally persisted to canonical market observations.
- `portfolio-mtm-refresh-v1`: ACTIVE v2. Verification request HTTP 200; 6 crypto legacy updates + 6 native USD publishes; no USD errors; no new Cron.
- CRWD: daily-close universe gap fixed by adding active canonical stocks at lowest existing priority. Targeted quota-guarded Twelve Data close passed.
- PR5 coverage: **70/70**, comprising **64 Stock LAST_CLOSE + 6 Crypto FRESH**, 0 MISSING.
- Tracker: hidden `_Market_Data` exists with 70 USD rows, separate USDTHB provenance and Sheet-side THB formulas. Existing `Price Data`, `Transactions`, `Holdings`, cost basis and P&L unchanged.
- Open holdings reconciliation: 10 unique assets mapped; mean absolute current-vs-shadow price delta ~0.87%; largest TTWO ~3.91%. Stock deltas mainly reflect live/current Price Data vs PR5 LAST_CLOSE semantics.

### Next MVP step

Do not spend the next cycle extending PR2–PR4 infrastructure. Decide/implement the simplest accepted stock pricing rule for the Tracker (live held-stock quote when valid, otherwise explicit LAST_CLOSE), rerun reconciliation, then make a separately reversible Price Data **read-only market-price source cutover**. Never change Transactions, quantities, cost basis or trading.

Phase-1 roadmap: `docs/implementation/PHASE1_MVP_FIRST_ROADMAP_20261016.md`.
