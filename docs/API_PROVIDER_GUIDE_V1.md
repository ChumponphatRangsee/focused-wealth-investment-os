# FWIOS API Provider Guide v1

**Status:** DESIGN REFERENCE — NO IMPLEMENTATION YET  
**Verified:** 2026-11-06  
**Scope:** Selected Provider Strategy v1 set; infrastructure still pending approval  
**Excluded:** Alpha Vantage

## Purpose

This document defines what each approved API is responsible for, the access conditions that FWIOS must respect, and the provider-specific rules that later infrastructure must enforce.

The v1 provider set is:

1. Massive
2. Twelve Data
3. SEC EDGAR / data.sec.gov
4. CoinGecko
5. Frankfurter

Optional providers such as FMP, Tiingo, EODHD and sec-api.io are not part of the required v1 runtime. They may be reconsidered only when a concrete capability gap is demonstrated.

## Global FWIOS provider rules

- Provider credentials must stay in server-side secret storage such as Supabase Vault; never commit keys to GitHub, logs, raw payloads or Google Sheets.
- Provider data must not directly mutate Transactions, Holdings quantities, Cost Basis, Manual Overrides or portfolio accounting.
- Raw/provider data is evidence, not canonical data, until identity, currency, session/date, freshness and provenance checks pass.
- Provider failure, quota exhaustion, partial batches, stale data or inconsistent sessions must fail closed.
- Bulk-universe workloads and focused portfolio/watchlist workloads are separate capability classes.
- Licensing must be re-evaluated before FWIOS becomes customer-facing, redistributes vendor data, or operates commercially.
- Historical evidence must remain immutable even if a provider is later retired.

---

## 1. Massive

### FWIOS role

**Primary for:**
- S&P 500 / broad US equity EOD market data
- bulk screening inputs
- normalized financial statements
- financial ratios
- baseline stock news / catalysts

**Not the primary source for:**
- authoritative SEC filing evidence
- crypto
- USD/THB reference FX
- current focused portfolio EOD while Twelve Data remains the approved focused provider

### Authentication

Massive requires an API key. REST examples support Bearer authentication.

Required secret name for future design:
- `MASSIVE_API_KEY`

Do not place the key in query logs or persisted source URLs.

### Market-data endpoints relevant to FWIOS

**Daily Market Summary**
- `GET /v2/aggs/grouped/locale/us/market/stocks/{date}`
- returns daily OHLC, volume and VWAP for all US stocks in one request
- intended use: one bulk request, then locally filter the S&P 500 universe

**Custom daily bars**
- `GET /v2/aggs/ticker/{ticker}/range/1/day/{from}/{to}?adjusted=false`
- use when a specific ticker/history range is required
- `adjusted=false` is mandatory when FWIOS needs as-traded/unadjusted price history

**Ticker reference**
- `GET /v3/reference/tickers`
- use for symbol/reference discovery and metadata

### Critical price rule

Massive stock aggregate bars are split-adjusted by default. FWIOS's unadjusted regular-close contract therefore requires:

`adjusted=false`

Do not accept the default adjusted result for canonical unadjusted EOD workflows.

### Free Stocks Basic conditions

Current individual Stocks Basic:
- cost: **$0/month**
- data recency: **end-of-day**
- history: **2 years**
- rate limit: **5 API calls/minute**
- individual/personal and non-professional use

Important timing:
- on the free Basic plan, the prior trading day's REST bars become available **after 00:00 America/New_York**
- before that point, the current trading day's EOD request can return HTTP 403

Therefore a free-tier bulk S&P 500 job must run after New York midnight, not immediately after the 16:00 close.

### Financials & Ratios

Relevant endpoints:
- `GET /stocks/financials/v1/income-statements`
- `GET /stocks/financials/v1/balance-sheets`
- `GET /stocks/financials/v1/cash-flow-statements`
- `GET /stocks/financials/v1/ratios`

Current individual access:
- Financials & Ratios Expansion: **$29/month**
- also included on eligible higher plans
- financial statement history reaches approximately **2009**, depending on company/filing availability
- financial statements are EOD data
- ratios are refreshed daily for active tickers

Use:
- screening
- normalized financial analysis
- valuation inputs
- comparison across companies

Do not treat normalized vendor fields as stronger evidence than the underlying SEC filing.

### Fundamental-data cautions

- Always store/report `period_end`, `filing_date`, `fiscal_year`, `fiscal_quarter`, and `timeframe`.
- Do not assume data was knowable at `period_end`; `filing_date` is the availability anchor.
- Expect amendments/restatements.
- A numeric zero in normalized data is not automatically proof that the issuer filed a literal zero.
- Ratio definitions can differ from other vendors; store provider lineage for derived metrics.

### News

Endpoint:
- `GET /v2/reference/news`

Conditions:
- included in all Stocks plans
- updated approximately hourly
- Stocks Basic exposes about 2 years of history
- includes ticker associations, publisher metadata, summaries and sentiment/insight fields when available

FWIOS use:
- catalyst discovery
- research queue inputs
- sentiment/context

News is secondary evidence. A relevant 8-K or other SEC filing outranks the article when determining a company-disclosed material event.

### Licensing boundary

Individual plans are for personal/non-professional use. Customer-facing display, redistribution, brokerage/commercial usage or large-user deployments require an appropriate Business license.

### FWIOS suitability

- ~500-stock bulk universe: **Excellent**
- 5–50 focused symbols: **Good**, but not the preferred primary while Twelve Data remains production-proven
- fundamentals: **Primary normalized provider**
- news: **Primary baseline provider**

Official sources:
- https://massive.com/stocks
- https://massive.com/docs/rest/stocks/overview
- https://massive.com/docs/rest
- https://massive.com/knowledge-base/categories/faq

---

## 2. Twelve Data

### FWIOS role

**Primary for:**
- focused Portfolio + Watchlist EOD market data
- approximately 5–50 stock symbols

**Fallback capability for:**
- crypto
- FX
- selected stock retries when the bulk provider path is unavailable

**Do not use as the default S&P 500 bulk provider.**

### Authentication

Requires an API key.

Existing/future secret:
- `TWELVE_DATA_API_KEY`

### Core EOD endpoint

`GET /time_series`

FWIOS stock EOD request requirements:
- `interval=1day`
- explicit symbol(s)
- USD stock data
- New York/exchange date validation
- unadjusted price mode: `adjust=none`
- returned session date must exactly match the intended market session
- reject partial/mixed-session batches

### Basic plan conditions

Current Basic:
- cost: **$0/month**
- API quota: **8 credits/minute**
- daily cap: **800 credits/day**
- daily quota resets at **00:00 UTC**
- trial WebSocket capacity: 8
- internal non-display usage
- supports US equities/ETFs, forex and crypto market data

### Credit accounting

Credits are endpoint-weighted.

For `/time_series`:
- approximately **1 API credit per symbol**

Examples:
- 4 symbols = 4 credits
- 50 symbols = 50 credits
- 500 symbols = 500 credits

This is why Twelve Data is suitable for a focused 5–50 stock workload but inefficient as the main ~500-stock scanner feed.

### Batch behavior

Two supported patterns:

**Multi-symbol same endpoint**
- comma-separated symbols
- one HTTP request can carry multiple symbols
- each symbol still consumes its endpoint credit

**JSON POST multi-endpoint batch**
- multiple subrequests can be sent in one POST
- each subrequest consumes its normal credits
- one failed subrequest does not imply that all other subrequests failed

Batching reduces HTTP/network overhead; it does **not** make credits free.

### Quota observability

Use:
- response headers `api-credits-used` and `api-credits-left`
- `/api_usage` endpoint when an explicit quota read is needed

Note:
- `/api_usage` itself consumes 1 API credit

The later infrastructure phase should record actual credit use rather than infer remaining quota from local counters alone.

### Fundamentals warning

Twelve Data fundamentals are much more expensive in credits. Their pricing documentation uses `/income_statement` as an example at **100 credits per symbol**.

Therefore:
- do not use Twelve Data as the primary 500-stock fundamentals source
- reserve it for focused fallback/enrichment only if necessary

### Licensing boundary

Basic is documented for internal non-display usage. External display, commercial distribution, exchange-specific data rights, or other expanded usage can require paid/business plans or add-ons.

### FWIOS suitability

- ~500-stock bulk market scan: **Poor/Fair**
- 5–50 focused EOD: **Excellent**
- fundamentals at scale: **Poor**
- fallback FX/crypto: **Good**

Official sources:
- https://twelvedata.com/pricing
- https://twelvedata.com/docs
- https://support.twelvedata.com/en/articles/5203360-batch-api-requests
- https://support.twelvedata.com/en/articles/5615854-credits
- https://support.twelvedata.com/en/articles/5713553-control-over-api-usage

---

## 3. SEC EDGAR / data.sec.gov

### FWIOS role

**Authoritative primary evidence for US public-company filings and XBRL facts.**

Use SEC data to:
- validate normalized fundamentals
- detect 10-K / 10-Q / 8-K / other filings
- capture filing dates and accession lineage
- source primary corporate evidence
- resolve conflicts between vendor-normalized data and the original filing

### Authentication

Public `data.sec.gov` APIs:
- **no API key**
- **no authentication required**

This is different from SEC filer-submission APIs. FWIOS only needs public data access for research/evidence.

### Fair-access limit

SEC current guidance:
- maximum **10 requests/second** total per user/IP workload
- excessive automated traffic may be temporarily blocked

FWIOS should set a lower internal ceiling to provide safety margin.

### Required User-Agent

Automated requests must declare a descriptive `User-Agent` that identifies the application/operator and contact information.

Future implementation must not send an anonymous/default bot User-Agent.

### Core endpoints

**Company submission history**
- `https://data.sec.gov/submissions/CIK##########.json`
- CIK must be 10 digits with leading zeros

**Company Facts**
- `https://data.sec.gov/api/xbrl/companyfacts/CIK##########.json`
- returns all supported standardized XBRL company concepts in one call

**Company Concept**
- `https://data.sec.gov/api/xbrl/companyconcept/CIK##########/{taxonomy}/{tag}.json`
- use when a single fact/concept is needed

**Frames**
- `https://data.sec.gov/api/xbrl/frames/{taxonomy}/{tag}/{unit}/{period}.json`
- useful for cross-company facts aligned to a calendar frame

### Bulk archives

Preferred for large-scale refresh:

**Company Facts bulk**
- `https://www.sec.gov/Archives/edgar/daily-index/xbrl/companyfacts.zip`

**Submissions bulk**
- `https://www.sec.gov/Archives/edgar/daily-index/bulkdata/submissions.zip`

SEC recompiles bulk ZIPs nightly, approximately **03:00 ET**.

Use bulk archives for large-universe refreshes instead of making hundreds/thousands of small repetitive requests.

### Freshness

SEC states:
- submissions API typical delay: **less than 1 second** after dissemination
- XBRL APIs typical delay: **under 1 minute**
- delays may increase during peak filing periods

### Data caveats

- CIK is the core issuer identity, not ticker.
- Company Facts contains standardized taxonomy concepts; custom issuer extension tags may not map directly.
- Fiscal calendars differ between companies.
- A calendar frame should not be treated as proof that issuers share identical fiscal periods.
- Filing amendments can change the evidence set.
- Store accession number, filing form, filing date and source URL/identifier with evidence.

### CORS

`data.sec.gov` does not support CORS for browser-style cross-origin use. FWIOS should access it server-side.

### FWIOS suitability

- primary evidence: **Mandatory / best source**
- 500-company refresh: **Excellent using bulk archives**
- targeted company validation: **Excellent**
- normalized turnkey ratios: **Not its role**; derive or use Massive and verify against SEC

Official sources:
- https://www.sec.gov/search-filings/edgar-application-programming-interfaces
- https://www.sec.gov/search-filings/edgar-search-assistance/accessing-edgar-data
- https://www.sec.gov/about/developer-resources
- https://data.sec.gov/

---

## 4. CoinGecko

### FWIOS role

**Primary crypto market-data provider.**

Use for:
- current crypto prices
- market cap / volume where required
- historical crypto market data
- crypto reference metadata

Current FWIOS crypto set can remain batched where the endpoint supports multiple coin IDs.

### Authentication

Demo and paid API access use CoinGecko API credentials according to the selected product/API base URL.

Future secret:
- `COINGECKO_API_KEY`

Do not persist the key in URLs/logs.

### Demo plan conditions

Current Demo:
- cost: **$0/month**
- **10,000 call credits/month**
- **100 requests/minute**
- 50+ endpoints
- data freshness starts from approximately **60 seconds**
- one API key
- historical daily coin data: about **1 year**
- **attribution required**

### Paid Basic reference

Current Basic:
- **$35/month billed monthly** or lower equivalent on annual billing
- 100,000 call credits/month
- 300 requests/minute
- freshness from approximately 10 seconds
- about 2 years historical coverage
- commercial license listed for paid plans

This is not required for FWIOS v1 unless the free Demo limits become insufficient or licensing requirements change.

### FWIOS usage target

For six current crypto assets, batch requests should keep usage small.

Illustrative call counts if one batch request covers the set:
- daily: ~30/month
- hourly: ~720/month
- every 15 minutes: ~2,880/month

All remain below the current 10,000 Demo monthly-credit cap.

### Data/licensing rules

- Free Demo usage requires CoinGecko attribution.
- Do not assume Demo data can be redistributed commercially.
- If FWIOS becomes commercial/customer-facing, reassess plan/license before launch.
- Track API credits and HTTP quota errors; do not blindly retry.

### FWIOS suitability

- crypto 5–50 assets: **Excellent**
- equities: not applicable
- FX reference rate: not preferred

Official sources:
- https://www.coingecko.com/en/api/pricing
- https://docs.coingecko.com/

---

## 5. Frankfurter

### FWIOS role

**Primary daily FX reference-rate provider**, currently especially USD/THB.

Use for:
- daily portfolio valuation conversion
- reference FX normalization
- historical daily FX evidence

Do not use it as a real-time executable FX trading feed.

### Authentication

Public API:
- **no API key**
- no account required for normal public requests

### Coverage

Current Frankfurter v2 public service:
- approximately **228 currencies**
- data from **106 central banks and official sources**
- daily updates
- historical coverage reaching back to **1948** for supported series
- open-source and self-hostable

### Recommended v2 endpoints

**Latest / general rates**
- `GET https://api.frankfurter.dev/v2/rates`

Useful filters include:
- `base`
- `quotes`
- `date`
- `from`
- `to`
- provider filtering where needed

**Single pair**
- `GET /v2/rate/{base}/{quote}`

**Historical single pair**
- `GET /v2/rate/{base}/{quote}/{date}`

**Provider metadata**
- `GET /v2/providers`

**Currency metadata**
- `GET /v2/currencies`

### v1 vs v2

Frankfurter v2 introduced multi-provider blended rates. v1 remains available but is the older API generation.

For new FWIOS infrastructure, prefer **v2** unless backward compatibility with the currently deployed path requires a staged migration.

### Freshness / semantics

Frankfurter is a **daily reference-rate** service.

Therefore:
- validate the rate's observation/date semantics
- allow for weekends/holidays and source publication timing
- do not label a carried reference rate as an intraday live quote
- retain source/provider metadata when possible

### Rate limiting / operational behavior

The public documentation does not publish a commercial quota comparable with Twelve Data/CoinGecko.

Therefore future FWIOS policy should:
- use low-frequency daily requests
- cache successful observations
- avoid aggressive polling
- handle HTTP 503 / Retry-After conservatively
- optionally self-host if control/reliability becomes important

### Licensing / deployment

Frankfurter is open source and can be self-hosted. Individual upstream official data sources may have their own source-data terms, so redistribution rights must still be reviewed if FWIOS becomes commercial.

### FWIOS suitability

- daily USD/THB valuation FX: **Excellent**
- intraday trading FX: **Not suitable as primary**
- historical reference rates: **Excellent**

Official sources:
- https://frankfurter.dev/
- https://github.com/lineofflight/frankfurter

---

## Provider responsibility map

| Capability | Primary provider | Fallback / verifier |
|---|---|---|
| S&P 500 daily bulk OHLCV | Massive | EODHD optional / Twelve focused retry |
| S&P 500 normalized fundamentals | Massive Financials & Ratios | SEC validation |
| Portfolio/watchlist stock EOD | Twelve Data | Massive |
| Primary filing evidence | SEC EDGAR | none required for authority |
| Company material-event evidence | SEC 8-K | Massive News for discovery/context |
| General stock news | Massive News | Tiingo optional |
| Crypto pricing | CoinGecko | Twelve Data |
| USD/THB daily reference FX | Frankfurter | Twelve Data FX |

## Provider usage classes

### BULK_UNIVERSE

Use for hundreds/thousands of assets:
- Massive Daily Market Summary
- Massive Financials & Ratios bulk-capable endpoints
- SEC nightly bulk archives

### FOCUSED_SYMBOL_SET

Use for approximately 5–50 assets:
- Twelve Data time series/batches
- targeted Massive ticker queries
- targeted SEC company APIs

### SPECIALIST_ASSET_CLASS

- CoinGecko for Crypto
- Frankfurter for FX

### PRIMARY_EVIDENCE

- SEC EDGAR

These capability classes should later drive Provider Registry and Capability Registry design. Providers must not be treated as interchangeable simply because two APIs can return a price.

## Cost baseline

Recommended v1 personal/internal configuration:

| Provider | Plan | Estimated recurring cost |
|---|---|---:|
| Massive Stocks | Basic | $0 |
| Massive Financials & Ratios | Expansion | $29/mo |
| Twelve Data | Basic | $0 |
| SEC EDGAR | Public API | $0 |
| CoinGecko | Demo | $0 |
| Frankfurter | Public API | $0 |

**Estimated recurring provider cost: approximately $29/month.**

This excludes taxes, currency conversion, future commercial licensing, paid fallback vendors and infrastructure costs.

## Explicitly excluded provider

**Alpha Vantage is not part of FWIOS Provider Strategy v1.**

It must not appear in the future:
- Provider Registry active provider set
- primary/fallback routing
- scheduled provider dependencies
- quota allocation
- new API documentation

Historical observations and historical operational receipts mentioning Alpha Vantage remain immutable evidence. Removal from the currently deployed runtime requires a separate approved implementation/cutover phase.

## Implementation gate

This document does **not** authorize:
- Supabase schema changes
- Provider Registry implementation
- worker changes
- Cron changes
- API-key provisioning/rotation
- new provider calls in production
- deletion/rewrite of historical provider observations
- portfolio accounting changes
- trading

Only after the provider design is approved should **Multi-Provider Data Infrastructure v1** be designed and implemented.
