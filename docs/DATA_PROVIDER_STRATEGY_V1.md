# FWIOS Data Provider Strategy v1

**Status:** APPROVED — PROVIDER STRATEGY v1, ARCHITECTURE DESIGN ONLY  
**User authorization:** 2026-11-09 (Asia/Bangkok); no procurement, provider activation, schema/runtime change, or implementation authorization  
**Date:** 2026-11-06  
**Runtime alignment checked:** 2026-11-09 (Alpha retirement deployed; Provider Strategy remains draft)  
**Phase:** Multi-Provider Infrastructure Architecture Design authorized  
**Implementation authorized:** No

**Decision-readiness audit (2026-11-09, historical preapproval review):** The appendix below documents the risks and conditional recommendation **before** the user's subsequent explicit approval. **Current decision:** Provider Strategy v1 APPROVED for Architecture Design only on 2026-11-09; its historical NOT APPROVED language is superseded by this current decision. All data-quality, licensing, point-in-time and E2E gates remain active. **No implementation authorization**.

## Decision summary

FWIOS should not use one provider for every workload. The recommended design separates **bulk-universe collection**, **focused portfolio/watchlist collection**, **primary evidence**, and **asset-class specialist feeds**.

Recommended v1 stack:

| Workload | Primary | Fallback / validation | Why |
|---|---|---|---|
| S&P 500 universe / bulk EOD screening | Massive Stocks Basic | EODHD or Twelve Data focused retry | Massive can return daily OHLCV for the entire US stock market in one request and supports unadjusted results |
| Portfolio + watchlist EOD (5–50) | Twelve Data | Massive Daily Market Summary | Twelve is already production-verified in FWIOS and is appropriate for focused symbol sets |
| Fundamentals / statements / ratios | Massive Financials & Ratios | SEC EDGAR / Company Facts; FMP optional enrichment | $29/mo individual add-on, daily ratios, 2009+ statements, broad US coverage, bulk-friendly query limits |
| SEC filings / primary evidence | SEC EDGAR / data.sec.gov | sec-api.io only if advanced full-text/search/streaming becomes necessary | Official primary source, no API key, real-time dissemination, nightly bulk archives |
| News / catalysts | Massive News + SEC 8-K monitoring | Tiingo News optional | Hourly structured news is enough for research; 8-K remains primary evidence for company material events |
| Crypto | CoinGecko | Twelve Data | Specialist crypto aggregator already used by FWIOS; generous free Demo quota |
| FX | Frankfurter | Twelve Data FX | Daily official-source reference rates, no key, open source, long history |


## Explicit provider exclusion

**Alpha Vantage is removed from Provider Strategy v1 by user decision on 2026-11-06.** It is not a primary, fallback, tertiary validator, or future dependency in this strategy. Historical production receipts that mention Alpha Vantage remain immutable historical evidence, but the future provider design must not require Alpha Vantage.

**Production alignment as of 2026-11-09:** Alpha Vantage was retired from the *active* runtime under separate user authorization (Stock Cron #17/#18 now Twelve-only, Market Worker v14, Alpha Vault credential removed). Historical Alpha price observations, quota receipts and read-side compatibility remain preserved. Autonomous post-cutover Twelve-only Stock EOD 4/4 + Sheet readback acceptance is still pending; do not manually invoke the worker or claim a new PASS. The completed Alpha cutover does **not** approve this broader Provider Strategy or Multi-Provider Infrastructure design/implementation.

## Architecture principle: bulk vs focused providers

### Bulk plane — approximately 500 stocks

Use a provider that can return **the market or a large cross-section in one request**.

Massive Daily Market Summary:
- endpoint: `/v2/aggs/grouped/locale/us/market/stocks/{date}`
- one request returns daily OHLC, volume and VWAP for all US stocks;
- available on the free Stocks Basic plan;
- Basic: 5 requests/minute, 2 years history, end-of-day;
- supports `adjusted=false`, which fits FWIOS's unadjusted regular-close contract;
- ideal for S&P 500 scanner input because FWIOS can filter the returned market locally.

Do not spend 500 separate provider calls merely to refresh the S&P 500 closing-price universe.

**Decision gate:** Massive's grouped feed returns the *whole US market*, not a licensed, point-in-time S&P 500 constituent list. Current and historical index membership, changes, issuer/share-class identity, and survivorship-bias handling must be separately specified before research/backtesting uses this as an S&P 500 universe.

### Focused plane — approximately 5–50 stocks

Twelve Data remains a good focused provider:
- Basic plan: 8 API credits/minute and 800/day;
- `time_series` is 1 credit per symbol;
- batch requests reduce HTTP overhead but each symbol still consumes its endpoint credit;
- 50 EOD symbols consume about 50 credits/day, well within the 800/day free allowance;
- 500 EOD symbols would consume about 500 credits/day and take roughly an hour at 8 credits/minute, so it should not be the bulk-universe path.

Current FWIOS production already has natural Twelve Data 4/4 EOD acceptance evidence, so Provider Strategy v1 should preserve this focused path until a later infrastructure phase explicitly changes it.

## Provider comparison matrix

| Provider | Best role | Coverage / depth | Quota / batch | Cost (personal/internal) | Freshness | Fundamental quality | Reliability / caveat | Licensing | ~500 stocks | 5–50 stocks |
|---|---|---|---|---:|---|---|---|---|---|---|
| Massive | Bulk US EOD + ratios + news | US market; Basic EOD 2y; financial statements from ~2009; ratios updated daily | Basic 5 req/min; one grouped EOD call covers all US stocks; ratios limit up to 50,000 rows | Stocks Basic $0; Financials & Ratios $29/mo | EOD on Basic; ratios daily; news hourly | Strong normalized US statements/ratios; not primary filing evidence | Good market-data fit; individual plans have no stated enterprise SLA | Individual-use plans; Business needed for customer-facing/display redistribution | **Excellent** | Excellent |
| Twelve Data | Focused EOD / fallback FX/crypto | Stocks/FX/crypto; broader paid plans | Basic 8 credits/min, 800/day; batch supported, credits still per symbol | $0 Basic; paid from Grow tier | EOD / real-time datasets depending asset and plan | Fundamentals cost high credits (e.g. statements 100 credits/symbol) | FWIOS has verified natural production successes | Internal non-display on Basic; plan/add-ons vary by use | Fair/Poor | **Excellent** |
| SEC EDGAR | Primary evidence + filings + XBRL | All SEC filers; submissions, filings, Company Facts; bulk archives | No key; fair-access max 10 req/s; nightly bulk ZIPs | $0 | Submissions typically near real-time; XBRL under ~1 min typical | **Highest authority**, but normalization is our responsibility | Government source; no product SLA/support | Public regulatory data; obey fair-access/User-Agent rules | **Excellent via bulk** | **Excellent** |
| CoinGecko | Crypto primary | 360+ chains, 2,000+ exchanges on paid ecosystem; broad market history | Demo 100 calls/min, 10,000 calls/month; 1 call = 1 credit | $0 Demo; Basic $35/mo | Real-time/historical crypto endpoints | N/A for equities | Strong crypto specialist; Demo has no SLA | Demo attribution required; commercial rights require paid plan | N/A | **Excellent for crypto** |
| Frankfurter | FX primary | 228 currencies; official/central-bank sources; long history | No API key; simple REST; self-hostable | $0 | Daily reference rates, not real-time trading FX | N/A | Simple and open-source; reference-rate use only | API/software open source; source-data terms still apply | N/A | **Excellent for daily FX** |
| FMP | Optional normalized fundamentals / enrichment | US on Starter; 30+ years on Premium; 100+ endpoints; news, statements, metrics | Starter 300/min; Premium 750/min; Ultimate 3,000/min; bulk/batch officially on Ultimate | Starter ~$22/mo; Premium ~$59/mo; Ultimate ~$149/mo on current annual-price page | Real-time/EOD depending endpoint | Very broad normalized fundamentals and ratios | Useful enrichment; unnecessary as mandatory v1 dependency if Massive+SEC covers core needs | Display/redistribution requires separate license | Good; **Excellent on Ultimate** | Excellent |
| Tiingo | Optional news / secondary multi-asset | 30+ years EOD; broad stocks/ETF; news; crypto/FX | Free 50/hour, 1,000/day; Power 10,000/hour, 100,000/day | $0 / $30 Power | News real-time; EOD market data | Fundamentals are a separate add-on with non-public price | Good secondary feed and rich news tagging | Individual/Power internal use only; redistribution separate | Fair on free; Good on Power | Excellent |
| EODHD | Low-cost bulk backup | 150k+ tickers; 30+ years EOD on paid; global | Paid plans 100k calls/day, 1,000/min; bulk EOD available | EOD plan $19.99/mo | EOD / delayed/live depending plan | Fundamentals plan separate; bulk fundamentals requires Extended plan | Broad/cheap, but vendor discloses some price feeds are aggregated/indicative rather than exchange feeds | Internal plan terms; check redistribution separately | **Good backup** | Good |

## Workload decisions

### 1. S&P 500 Universe / Bulk Screening

**Primary: Massive Stocks Basic + Financials & Ratios.**

Market-data refresh should be one Daily Market Summary request, then filter S&P 500 constituents locally. The Financials & Ratios endpoint can return up to 50,000 rows and supports server-side ratio filters/sorting, which makes it far more suitable for 500-stock screening than per-symbol requests.

Use SEC Company Facts and filings to validate high-conviction candidates rather than treating normalized vendor metrics as primary evidence.

### 2. Portfolio + Watchlist EOD

**Primary: Twelve Data. Fallback: Massive.**

Reason: FWIOS already has verified fail-closed Twelve Data EOD behavior and natural 4/4 production runs. For 5–50 symbols, the free Basic allowance is adequate.

Do not extend Twelve Data into the 500-stock bulk scanner merely because it is already integrated.

### 3. Fundamentals / Financial Statements / Metrics

**Primary normalized provider: Massive Financials & Ratios ($29/mo).**

Coverage is sufficient for the S&P 500. Ratios include valuation, profitability, liquidity and leverage metrics such as P/E, P/B, P/FCF, EV/EBITDA, ROA, ROE, FCF and market cap. Statements cover income statement, balance sheet and cash flow with quarterly/annual/TTM data, with history from around 2009.

**Authoritative validation: SEC Company Facts + filing documents.**

FMP Premium should be treated as an optional enrichment provider if FWIOS later needs broader history, estimates, analyst data, custom DCF inputs, or data fields missing from Massive.

### 4. SEC Filings / Primary Evidence

**Primary: SEC EDGAR direct.**

Use:
- `data.sec.gov/submissions/CIK##########.json`
- Company Facts API
- filing documents from EDGAR Archives
- nightly `companyfacts.zip` and `submissions.zip` for large-scale refreshes

SEC states the APIs require no authentication, submissions are updated in real time, XBRL APIs typically update within a minute, and fair-access guidance caps automated access at 10 requests/sec.

**Optional fallback: sec-api.io** only if FWIOS later needs low-latency filing streams, full-text search, ready-made item extraction or operational support. It starts at $55/month billed monthly ($49 annual-equivalent) for personal/startup usage, so it is not necessary for v1.

### 5. News / Catalysts

**Primary v1: Massive News + SEC material filings.**

Massive's news endpoint is available on Stocks Basic, updated hourly, and Basic exposes two years of history. This is adequate for an investment-research catalyst pipeline that does not require sub-second news trading.

SEC 8-K should outrank secondary news when the catalyst is a company-disclosed material event.

**Optional upgrade: Tiingo Power ($30/mo)** if FWIOS later needs broader real-time article discovery and richer tagging. Tiingo reports approximately 8,000–12,000 new articles/day in its news feed and offers three months of queryable news history on Power.

### 6. Crypto

**Primary: CoinGecko Demo. Fallback: Twelve Data.**

CoinGecko Demo currently allows 100 calls/minute and 10,000 calls/month. A single batch price request for the current six FWIOS crypto assets is far below this ceiling.

If refreshed every 15 minutes, one batched call per interval is about 2,880 requests/month, still below the free 10,000-call cap.

### 7. FX

**Primary: Frankfurter. Fallback: Twelve Data FX.**

Frankfurter is appropriate because FWIOS uses USD/THB for valuation/reference conversion, not intraday FX trading. It uses central-bank and official-source reference rates, requires no API key, and can be self-hosted.

## Estimated FWIOS API usage

Assumptions:
- ~22 US trading sessions/month
- ~500-stock screening universe
- up to 50 focused stock symbols
- 6 crypto holdings/watchlist assets

### Bulk stock market data — Massive

Daily Market Summary:
- 1 request/session
- about **22 requests/month** for the entire US equity market

A one-time two-year Basic bootstrap using one grouped request per historical session is roughly 500 requests; at 5 requests/min it takes about 100 minutes, but it is a one-time cache population rather than recurring production load.

### Fundamentals — Massive Financials & Ratios

An illustrative minimum batch of:
- ratios: 1 request
- income statements: 1 request
- balance sheets: 1 request
- cash flows: 1 request

is **at least 4 requests/trading day (~88 requests/month as a lower bound)** before pagination, retries, extra periods or per-symbol coverage checks. Actual usage must be measured from response metadata and `next_url`, rather than assuming four calls always cover the full 500-name financial history.

In practice statements should become filing/event-driven, so steady-state usage can be lower.

### Focused Stock EOD — Twelve Data

For 50 symbols:
- 50 credits/trading day
- approximately **1,100 credits/month**
- still only 50 of the Basic plan's 800-credit daily allowance
- about 7 minutes minimum elapsed provider budget at 8 credits/minute for a full 50-symbol batch

Current four-stock portfolio usage is only about 88 symbol credits/month if run every US trading day.

### SEC evidence

Nightly bulk approach:
- Company Facts bulk archive: ~1 download/day
- Submissions bulk archive: ~1 download/day
- around **60 bulk downloads/month**, plus targeted filing-document fetches only when new evidence is required

### Crypto — CoinGecko

If batched:
- daily: ~30 calls/month
- hourly: ~720 calls/month
- every 15 minutes: ~2,880 calls/month

All are under the current 10,000-call Demo cap.

### FX — Frankfurter

One USD/THB reference refresh/day:
- about **30 requests/month**

### News — Massive

Eight hourly scans per US trading day:
- about **176 requests/month**

## Cost scenarios

### Recommended v1 — lean

- Massive Stocks Basic: $0
- Massive Financials & Ratios: **$29/mo**
- Twelve Data Basic: $0
- SEC EDGAR: $0
- CoinGecko Demo: $0
- Frankfurter: $0
- Massive News on Basic: $0

**Estimated recurring provider cost: about $29/month.**

This is the recommended starting point for FWIOS as a personal/internal investment system.

### Optional richer-news configuration

Add Tiingo Power:
- +$30/month

**Total: about $59/month.**

### Optional deeper normalized-fundamentals configuration

Add FMP Premium:
- +about $59/month on the current annual-billing pricing page

**Total with Massive Financials + FMP Premium: about $88/month.**

This should be deferred until a concrete data gap justifies the second paid fundamentals vendor.

## Licensing boundary

The recommended low-cost plans are suitable for the current **personal/internal FWIOS** use case.

If FWIOS later becomes:
- a public dashboard,
- a customer-facing SaaS,
- an API that redistributes vendor data,
- or a paid product displaying source data,

provider licensing must be re-evaluated. Massive individual plans, Tiingo individual plans, FMP personal plans and CoinGecko Demo/paid tiers have different display/redistribution rights. Do not assume a personal subscription grants redistribution rights.

## Final Provider Strategy v1 recommendation

Adopt a provider portfolio, not a universal provider:

1. **Massive = bulk US equity market + normalized fundamentals/ratios + baseline news.**
2. **Twelve Data = focused 5–50 stock EOD provider and multi-asset fallback.**
3. **SEC EDGAR = primary corporate evidence and filing truth.**
4. **CoinGecko = crypto specialist.**
5. **Frankfurter = daily FX reference specialist.**
6. **FMP / Tiingo / EODHD = optional secondary providers activated only when a defined capability gap justifies their cost.**

This strategy minimizes cost and provider calls while preserving the strongest source for each workload. It also gives the later Multi-Provider Infrastructure phase a clear reason to distinguish capability classes instead of building generic failover between interchangeable vendors.

## Approval gate — updated 2026-11-09

**Satisfied for design:** The user explicitly approved Provider Strategy v1 and authorized Multi-Provider Infrastructure Architecture Design on 2026-11-09. This is **NOT** authorization to procure paid subscriptions, issue new provider credentials, create new database objects, deploy workers, add Crons, modify live prices, access paid APIs, or begin implementation.

The authorized design phase covers:
- Provider Registry
- Capability Registry
- Quota / Rate-Limit Policy
- API Call Ledger
- Raw Provider Data
- Normalization
- Canonical Data
- Validation / Quality
- Provider failover

**Design outputs:** See `docs/database/planned/DB-ARCH-2.0/MANIFEST.yaml` for the separate planned architecture and approval gates. `docs/database/CURRENT.yaml` continues to identify the verified live DB-ARCH-1.0.

No production runtime, database schema, Cron, Worker, provider credential, Google Sheet accounting, or trading behavior is changed by this document.

## Official research sources

- Massive pricing and Stocks API documentation
- Twelve Data pricing and batch-request documentation
- SEC EDGAR APIs and Developer/Fair Access documentation
- CoinGecko API pricing and licensing documentation
- Frankfurter API and open-source repository documentation
- Financial Modeling Prep pricing, screener, bulk and batch documentation
- Tiingo pricing and News API documentation
- EODHD pricing and bulk-fundamentals documentation
- sec-api.io pricing documentation

---

## Decision Readiness Audit — 2026-11-09 (evidence and approval gates)

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
