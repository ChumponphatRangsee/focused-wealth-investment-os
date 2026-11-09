# FWIOS Data Provider Strategy v1

**Status:** DRAFT — PROVIDER SET REVISED; INFRASTRUCTURE PENDING APPROVAL  
**Date:** 2026-11-06  
**Runtime alignment checked:** 2026-11-09 (Alpha retirement deployed; Provider Strategy remains draft)  
**Phase:** Research / architecture decision only  
**Implementation authorized:** No

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

A conservative daily pull of:
- ratios: 1 request
- income statements: 1 request
- balance sheets: 1 request
- cash flows: 1 request

is about **4 requests/trading day = ~88 requests/month**, because the endpoints support large result limits.

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

## Approval gate

No Multi-Provider Data Infrastructure design or implementation should begin until the user explicitly approves this Provider Strategy v1.

After approval, the next phase may design:
- Provider Registry
- Capability Registry
- Quota / Rate-Limit Policy
- API Call Ledger
- Raw Provider Data
- Normalization
- Canonical Data
- Validation / Quality
- Provider failover

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
