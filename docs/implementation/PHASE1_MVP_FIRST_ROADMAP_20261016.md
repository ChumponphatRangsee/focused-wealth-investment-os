# FWIOS v3 — Phase 1 MVP-First Roadmap

**Decision date:** 2026-10-16  
**Goal:** Make the investment workflows usable end-to-end before expanding infrastructure for scale.

## Product-first rule

Phase 1 optimizes for a single-owner / very-low-user-count system. Existing PR2–PR4 quota, reservation, cache and single-flight foundations are retained but **feature expansion and enterprise-scale acceptance work are frozen unless needed to ship a working feature**.

Do not remove safety-critical controls: secrets stay server-side, provider calls remain bounded, historical currency/provenance is truthful, transactions/cost basis are never silently rewritten, and automated trading remains off.

## Phase 1 sequence

1. **PR5 Native USD market data — working MVP**
   - Stocks + crypto expose native USD canonical observations.
   - Reuse existing provider calls where possible; avoid duplicate network requests.
   - Explicit FRESH / LAST_CLOSE / MISSING semantics.
   - Current receipt: 70/70 supported assets covered.

2. **PR6 Portfolio Tracker shadow — working MVP**
   - Hidden `_Market_Data` receives canonical USD snapshot plus separate USDTHB.
   - Google Sheets calculates THB shadow values.
   - Compare against current Price Data/Holdings without changing accounting.
   - Current receipt: implemented; open holdings shadow reconciliation complete.

3. **PR7 Price Data read cutover — only after semantic acceptance**
   - Decide whether stock valuation uses last close, live quote, or explicit fallback.
   - Replace only market-price read formulas; never rewrite Transactions/Cost Basis.
   - Keep immediate rollback to old read path.

4. **Focused Dashboard MVP**
   - Scanner/research uses the shared market-data source for the subset of features actually used.
   - Do not block on full S&P 500 enrichment or advanced scheduling.

## Deferred technical backlog

Until real user/load evidence requires it:
- 20-session distributed concurrency proof;
- richer P0–P4 scheduler behavior;
- advanced quota analytics and alerting;
- multi-user authorization/scaling;
- full-universe enrichment and high-frequency refresh.

These are not deleted; they are intentionally postponed.

## Phase 1 success

A normal workflow should be possible without SQL/GitHub intervention:
- Tracker shows trustworthy prices and portfolio values;
- Dashboard supports useful discovery/research;
- prices expose freshness/source;
- failures degrade visibly instead of corrupting accounting;
- no automated trade execution.
