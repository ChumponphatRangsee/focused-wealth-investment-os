# FWIOS Provider Strategy v1 — Decision Readiness Review

**Review date:** 2026-11-09 (Asia/Bangkok)  
**Decision status:** **REVIEW COMPLETE — CONDITIONALLY RECOMMENDED FOR DESIGN-ONLY APPROVAL; NOT APPROVED**  
**Scope:** Research and documentation only. No provider procurement, infrastructure design authorization, runtime changes, database migrations, worker invocations or production tests.  
**Baseline:** `docs/DATA_PROVIDER_STRATEGY_V1.md`, `docs/API_PROVIDER_GUIDE_V1.md`, `contracts/system-contract.yaml`, `docs/PRICE_PIPELINE.md`, and `docs/database/CURRENT.yaml` on `main` as of 2026-11-09. The production E2E handoff retains its own pending acceptance gates.

## 1. Decision recommendation

Retain the *multi-specialist* provider allocation as the **proposed design baseline**, but do not declare the wider strategy unconditionally approved:

| Workload | Proposed source | Decision readiness | Boundary |
|---|---|---|---|
| Broad US stock EOD / ~500-name screening | Massive Stocks Basic grouped daily OHLCV | **Recommended, with timing + constituent-feed gates** | Access the free-tier prior session only after NY midnight; `adjusted=false`; never assume a grouped US-universe response is the S&P 500 membership list |
| Focused stock EOD, 4 currently open stocks / later 5–50 | Existing Twelve Data | **Retain current production path** | The 4-stock current contract is not automatically upgraded to 50; stock symbol onboarding and independent quota/atomicity validation are separate |
| Normalized statements and current ratios | Massive Financials & Ratios ($29/mo personal) | **Optional / paid activation gated** | No subscription or new key until explicit approval and actual field/coverage sample validation; do not treat revised financial history as point-in-time truth |
| Original filings, filing dates, primary fundamental evidence | SEC EDGAR and Company Facts | **Recommended** | Server-side access, identifiable User-Agent, reasonable rate cap, accession-linked source evidence |
| Stock news and catalysts | Massive ticker News + SEC 8-K | **Recommended for non-latency-critical research** | Hourly updates, article-time vs ingestion-time distinction, SEC source for material company disclosures |
| Crypto | Existing CoinGecko | **Retain current production path** | Demo usage and attribution limits; crypto Cron #20 autonomous acceptance is separate and pending |
| USD/THB FX | Existing Frankfurter | **Retain current production path** | Daily reference rates, not a trading-rate quote; explicitly document blended-vs-pinned-provider semantics |
| Failover | Capability-specific sources, not blind substitution | **Design-only proposal** | No automatic fallback until source/session/currency/price-adjustment/licensing/quality gates are designed, reviewed, and tested |

**Alpha Vantage remains fully excluded** from future active-provider routing. Preserve historical Alpha observations and quota receipts; do not reintroduce its retired credential, worker mode or Cron.

## 2. External official-source checks (2026-11-09)

1. **Massive bulk EOD:** Grouped Daily Market Summary is offered on Stocks Basic. Basic advertises $0, 5 requests/minute, and two years' history. Its same-day market bars become available **after 00:00 America/New_York on the following day**; trying to pull the current NY trading date before midnight may return 403. Grouped aggregates are split-adjusted **by default**, so the FWIOS unadjusted-price design must request `adjusted=false` and validate the response flag.  
   Sources: [Stocks overview](https://massive.com/docs/rest/stocks/overview), [pricing](https://massive.com/pricing?product=stocks), [free EOD timing](https://massive.com/knowledge-base/article/on-the-free-basic-plan-when-can-i-pull-the-previous-trading-days-data), [Daily Market Summary](https://massive.com/docs/rest/stocks/aggregates/daily-market-summary).
2. **Massive financials:** Financials & Ratios is listed at **$29 per month** for personal use; statements are separate Income, Balance Sheet and Cash Flow endpoints, with a fourth **daily latest/TTM ratios endpoint**. Ratios are **not a historical point-in-time ratio series**. The official vendor states that its statement records can reflect subsequent restatements and that the displayed `filing_date` can refer to the latest filing including a period rather than the first filing in which the fact was knowable. Therefore **as-of backtests require original SEC accession/filing history and point-in-time stored observations**, not a present-day API backfill treated as historical truth. Pagination may increase call counts; `next_url` and 100-row defaults must be accounted for.  
   Sources: [Financial pricing](https://massive.com/pricing?product=stocks), [four financial endpoints](https://massive.com/knowledge-base/article/what-fields-can-i-expect-from-massives-financials-api), [ratios docs](https://massive.com/docs/rest/stocks/fundamentals/ratios), [filing date/restatement caveat](https://massive.com/knowledge-base/article/does-massive-provide-the-filing-date-for-any-financial-reports).
3. **Twelve Data:** Basic advertises **8 credits/minute and 800/day** with internal non-display usage. A three-symbol `time_series` request consumes three credits, so batching does not erase per-symbol usage. For 50 one-credit symbols, the theoretical minimum rate-limited service spans at least seven minute windows, ignoring scheduling, retries and other calls. Personal EOD plans are not general permission for commercial redistribution.  
   Sources: [pricing](https://twelvedata.com/pricing), [credits](https://support.twelvedata.com/en/articles/5615854-credits), [EOD licensing](https://support.twelvedata.com/en/articles/12682324-end-of-day-eod-pricing-market-data).
4. **SEC EDGAR:** Public `data.sec.gov` endpoints need no key. SEC offers submissions and standardized XBRL Company Facts; bulk ZIP archives are republished nightly. Fair-access guideline is **no more than 10 requests/second per user**, with identifiable automation and controlled concurrency. XBRL API facts cover standardized taxonomies and may omit custom extension facts; issuer fiscal reporting periods must not be inferred from calendar frames.  
   Sources: [official EDGAR APIs](https://www.sec.gov/search-filings/edgar-application-programming-interfaces), [Developer Resources](https://www.sec.gov/about/developer-resources).
5. **CoinGecko:** Demo currently lists **10,000 call credits/month**, **100 calls/minute**, with attribution required. The vendor's Oct 2026 clarification says successful HTTP 200 calls deduct monthly credit; all requests, including failures, count against minute-rate limits.  
   Sources: [pricing](https://www.coingecko.com/en/api/pricing), [usage accounting](https://support.coingecko.com/articles/1864417806-how-does-coingecko-api-count-the-api-usage-credit).
6. **Frankfurter:** Public v2 is keyless and self-hostable, but its *default* result can be a **blend of official providers** rather than a single central bank's exact quoted rate. If the downstream use requires a specified authority, pin the provider and retain that identity; official source terms can still apply. Do not represent a weekend carry as live FX.  
   Sources: [v2 documentation](https://frankfurter.dev/), [provider pinning](https://frankfurter.dev/javascript/), [data license](https://frankfurter.dev/license/).
7. **News / rights:** Massive ticker news is available on Basic and updated hourly, but that is not a real-time event stream; record `first_seen_at` separately from publisher `published_utc`. Massive states that personal/individual plans do **not** grant sharing/redistribution rights; a dashboard/app exposed even to another user requires a compatible commercial license.  
   Sources: [News endpoint](https://massive.com/docs/rest/stocks/news), [news archival semantics](https://massive.com/knowledge-base/article/how-far-back-does-massives-news-and-sentiment-data-go), [Massive redistribution](https://massive.com/knowledge-base/article/how-can-i-redistribute-massives-market-data), [personal app eligibility](https://massive.com/knowledge-base/article/which-plan-do-i-need-to-show-massive-data-in-my-app).

**Research confidence:** Provider-published capabilities/prices/terms are verified as advertised, **not** by making authenticated calls from the user's account or examining entitlements, invoices, API credit headers, actual schema coverage, subscription status, or legally binding commercial agreements. These remain explicit gates.

## 3. Request and spend model (estimated, not a provider entitlement test)

| Workload | Conservative example | Implication |
|---|---|---|
| Massive grouped EOD | 1 successful response/trading date × ~22 dates = **~22 requests/month** | As long as the US-market grouped endpoint, current date entitlement and request limits remain valid; source S&P 500 membership separately |
| Massive historical two-year free bootstrap | ~500 trading-date calls at 5/min | **~100 minutes lower bound**, excluding holidays, retries and errors; free entitlement covers only the most recent 2 years |
| Massive statements/ratios | 1 ratios + 3 financial statement endpoints per pull = **4 calls minimum per batch** | Not a guaranteed 4 calls/day: paginate, restrict `timeframe`, and use changed filing windows; avoid 500-company full-history re-downloads every day |
| Twelve Data at 4 stocks | 4 credits/session × ~22 = **~88 credits/month** | Fits current workload; independently monitor 8/minute and Basic 800/day |
| Twelve Data at 50 stocks | 50 credits/session × ~22 = **~1,100 credits/month** | Daily count still < 800; per-minute scheduling and the system contract's **15-symbol max** require separately approved design before any scope increase |
| CoinGecko 6 crypto assets batched | ~30/month daily; ~720/month hourly; ~2,880/month at 15 min | Only illustrative; do not change existing production Cron cadence under this review |
| Frankfurter reference FX | ~30 low-frequency requests/month | Reuse existing verified path; do not assume an intraday execution quote |
| SEC bulk archives | Up to ~2 archive downloads/night | HTTP count alone understates bandwidth, decompression/storage and processing cost |
| Massive news | 8 scans/trading day × 22 = **~176 request opportunities/month** | Pagination/dedup and any delayed source ingestion can raise actual requests |

**Monthly cash scenarios:**
- **$0 provider pilot:** existing free Twelve/CoinGecko/Frankfurter/SEC plus Massive Stocks Basic for *future* read-only research after separately authorized provider access. This is a provider subscription estimate, not a request to create keys or invoke endpoints.
- **$29/mo targeted fundamentals:** purchase Massive Financials & Ratios **only after** its sample schema, filing coverage, non-professional eligibility and ongoing value to FWIOS are accepted. Approx **$348/year**, excluding tax, exchange fees, other paid services and infrastructure.
- **$59+/mo** optional news/enrichment stack is **not recommended yet**. Secondary provider/fallback bills and commercial licenses have not been proven necessary.

## 4. Blocking questions and risk treatment

| ID | Issue | Severity | Required answer before *implementation* |
|---|---|---|---|
| R1 | **S&P 500 constituent identity and history** are not provided by a grouped all-stock-price endpoint | HIGH | Define legal/accurate current membership source, effective-date changes, company/share-class IDs, delistings and historical membership or label tests as current-universe-only. Never backtest old dates on today's members without a survivorship-bias warning |
| R2 | **Look-ahead and restatement bias** in third-party fundamentals | CRITICAL for research/backtesting | Separate `period_end`, `first_public_filing_at`, `accession`, `source_as_of`, `ingested_at`, restatement/version and per-metric lineage. Backtest only data actually available by the simulated decision time |
| R3 | **Licensing**: own personal portfolio vs job/employer/public dashboard/SaaS redistribution | HIGH | Explicit intended-user/licensing decision; obtain vendor permission/appropriate tier before exposing data beyond personal use |
| R4 | **EOD timing and adjustment** mismatches | HIGH | Massive Basic next-day midnight ET rule; Twelve confirmed provider session; `adjusted=false`; regular close only; no stale backdating or live-quote substitution |
| R5 | **Unverified provider entitlement/coverage** (ratio fields, missing symbols, plan inclusion and historical depth) | MEDIUM/HIGH | Narrow authorized test plan with a small symbol sample including financial and nonfinancial companies; measure missing fields, timestamps, errors, response pagination, rate headers, and real call count |
| R6 | **Blind fallback / silent provider substitution** | HIGH | Gate each provider by capability, official vs aggregated rate, exchange/session, currency, adjustment, reference identity, source tier, freshness and audit lineage; no fallback that bypasses blocked price state |
| R7 | **Scope collision with price-only architecture** | HIGH | `ASSET-PRICE-CONTRACT-1.1.0` explicitly excludes `stock_discovery`, `fundamental_research`, `valuation`, `scoring_and_decision`. Design those separately; do not repurpose the deployed two Edge Workers or `fwios.market_observations` as a general financial-statement store |
| R8 | **E2E acceptance unresolved** | ACCEPTANCE GATE | Existing Crypto Cron #20 and post-cutover Twelve-only 4/4 EOD-to-Sheet cycle remain PENDING. Do not trigger them or treat this research as new production acceptance |

### Specific clarification on valuation
The vendor's current ratios (P/E, EV/EBITDA, etc.) can aid **screening**, but cannot alone produce an adequately justified **Fair Value**. A later, separately scoped research system needs filing-level evidence, forecasts/assumptions, model routing, discount rate, capital structure, sensitivity analysis, as-of lineage and quality/decision gates. No such research or valuation runtime is authorized by this price-service review.

## 5. Approval stages and acceptance gates

**Stage A — user approval of provider strategy for architecture design ONLY:** Approve the conceptual responsibilities, $0-first spend policy, Alpha exclusion, and risk controls above. This permits *design work* only, not billing, new API credentials, migrations, live tests, or deployment.

**Stage B — design review (separate):** Write an architecture/spec comparing scoped Registry/Capability definitions, rate-limit and dedupe, raw-vs-canonical lineage, independent Research vs Price Service boundaries, provider legal/entitlement gates, failure modes and rollout/rollback plan. Define point-in-time membership and fundamentals as first-class requirements.

**Stage C — implementation authorization (separate):** Only after a reviewed spec may a new branch/PR, CI fixture and integration tests, guarded migration (if needed), authenticated provider testing, controlled deployment, and postflight verification be explicitly approved. Preserve `auto_trade=false`, existing price history, manual overrides and Google Sheet accounting.

**Do not proceed to Stage B or C automatically.** No future provider should be routed through active production on the strength of this review.

### Suggested explicit decision wording — NOT YET GIVEN

> Approve FWIOS Provider Strategy v1 as a **design-only baseline**, retaining Twelve Data for focused EOD, Massive for future bulk EOD + optional paid fundamentals, SEC for primary evidence, CoinGecko for crypto, Frankfurter for FX, and excluding Alpha Vantage. Preserve the eight risk gates above. Authorize architecture design only; no credentials, spending, production write, migration, worker invocation, or deployment without separate approval.

## 6. Review completion receipt

- Source-reviewed `main` documents and official public vendor references on 2026-11-09; no authenticated provider requests.
- No newly created active system, Supabase migration, Cron/Edge changes, Sheet transaction/accounting write, or portfolio snapshot.
- Both autonomous E2E tasks deliberately parked at `PENDING_SCHEDULED_RUN`; GitHub Issue #106 remains open.
- Decision is **not approved** merely by merging this review documentation; proposal for user decision only.
