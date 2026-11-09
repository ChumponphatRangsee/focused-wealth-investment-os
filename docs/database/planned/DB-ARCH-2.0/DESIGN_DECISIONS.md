# DB-ARCH-2.0 — Design Decisions / ADRs
**STATUS: PLANNED / NOT DEPLOYED**. The **Provider Strategy v1 is approved** for architecture design. No subsequent decision in this design document authorizes implementation, procurement, credential activation or a production write. **Safety invariant:** `auto_trade=false`; no Transactions, Holdings quantities, Cost Basis, Manual Overrides, canonical price history or account mutation.

## ADR-001 — Keep existing Price Service independent
**Selected:** Keep the current `ASSET-PRICE-CONTRACT-1.1.0` and its 3 `fwios` price tables, historical Alpha rows, 2 active workers and current Google Sheet accounting intact. Create planned Research and Provider domains outside the price-service schema. A separate approved, versioned bridge is required to import any Research data into priced holdings.

**Rejected:** Extend the production Market Worker into a 500-stock provider crawler or resurrect the retired scanner, valuation snapshot, portfolio backend, or old EOD Cron. **Reason:** violates current price-only contract and risks mixing research quotes with certified held-asset closes.

## ADR-002 — Distinguish Provider Control Plane from Evidence Plane
**Selected:** `fwios_provider` controls provider eligibility, capabilities, routes, quotas and requests; `fwios_research` holds source-backed research identity, bars, filings, facts and news. Each private schema has independent least-privilege policies.

**Rejected:** A single catch-all provider table and arbitrary JSON per ticker. **Reason:** legal rights, publication lags and evidence types are not interchangeable.

## ADR-003 — Provider-specific capabilities, not vendor-level "fallback"
**Selected:** Model `BULK_EOD_US`, `FOCUSED_EOD_US`, `NORMALIZED_FINANCIALS`, `PRIMARY_SEC_EVIDENCE`, `CATALYSTS_NEWS`, `CRYPTO_SPOT`, and `FX_REFERENCE_USDTHB` with strict provenance/session/adjustment/license policies. Auto-fallback default **false**.

**Rejected:** If an endpoint fails, call any provider with a "price" field. **Reason:** adjusted close, stale last trade, SEC filing, crypto quote and official FX rate have different meanings.

## ADR-004 — Share architecture, not the existing price-only quota ledger
**Selected:** A future general-purpose atomic `fwios_provider.request_ledger` uses a deterministic request fingerprint and account-specific cost ceilings. The deployed `fwios_quota.api_call_ledger` remains the separate price-service ledger; historical receipts and idempotency remain unchanged.

**Rejected:** Reusing/deleting/migrating the existing price-specific quota receipts as a shortcut. **Reason:** current active Twelve/Data EOD 4/4 protected reservations and stable price-operation audit must not be disturbed.

## ADR-005 — One bulk market call; no 500-signal API loop
**Selected:** Massive grouped daily market data for future unadjusted broad stock EOD, then filter against a source-backed index membership list. Twelve Data is preserved for the small holdings/watchlist focus; a 50-name research target is not permission to raise the live price worker's `max_symbols: 15`.

**Rejected:** Five hundred independent Twelve Data per-symbol price requests as the default S&P 500 pipeline.

## ADR-006 — Point-in-time membership and filing availability are first-class
**Selected:** A separate dated `index_memberships` source plus SEC accession/acceptance times and immutable versions. The `first_public_at` for facts and known-at for membership are mandatory for credible as-of backtests. If historical membership rights/history unavailable: mark `CURRENT_UNIVERSE_ONLY` and block historical-membership claims.

**Rejected:** Using today's S&P 500 constituents with past EOD bars, or treating a latest restated vendor number as known at old period end.

## ADR-007 — Primary evidence outranks vendor normalization
**Selected:** SEC EDGAR accession-level documents and Company Facts establish authoritative reported facts. Massive financial ratios/statements can accelerate normalization/screening, but must be reconciled to primary evidence for conviction-grade work. Vendor-only facts without first-public evidence cannot receive historical-as-of PASS.

**Rejected:** Treat P/E or EBITDA API field as sufficient to create a fair value or decision with no filing lineage.

## ADR-008 — Immutable versions with separate retention rights
**Selected:** Append or supersede via new versioned evidence identifiers; preserve original observations and a non-destructive correction trail. Keep request idempotency ledger until a safe redesigned expiry mechanism is separately approved. Treat raw article/payload caching rights independently from audit metadata and hashed receipt; never retain restricted full text by default.

**Rejected:** Overwrite historical SEC data and backdate the new fact to the old fiscal period without noting amendment.

## ADR-009 — Explicit publication and regular-close semantics
**Selected:** For Massive Free Basic, guard fetch until after New York midnight and validate returned session. Request `adjusted=false` for research unadjusted OHLCV. The production Twelve-only Stock Cron #17/#18 timing and full-batch requirements are unchanged.

**Rejected:** Running a free Massive current-session EOD fetch immediately after the exchange close or using default adjusted data.

## ADR-010 — Cost controls and licensing before credentials
**Selected:** No new provider calls or paid subscriptions under design approval. Proposed initial provider spend ceiling is **$0 additional**; optional $29/month Massive Financials & Ratios is gated behind a separate purchase and exact data-license/entitlement decision. Commercial display and redistribution require new licensing checks even if a dataset is technically available.

**Rejected:** Create keys or subscribe automatically because a cost estimate appears in the Strategy.

## ADR-011 — Minimal server-only dispatch, no unnecessary generic gateway
**Selected:** A proposed internal dispatcher/adapter in an isolated future research service, behind server authentication, private schemas and typed capability routes. Leverage Postgres transactionally for durable reservations; optionally add a queue if workloads show a real need.

**Rejected:** Publicly exposed generic market-data API gateway, browser-visible keys, or automatically launching a new gateway product before evidence of need.

## ADR-012 — Risk-managed rollout with reversible feature gates
**Selected:** Start with schema/contract/fixtures in isolation only **after** separate implementation approval, then 3–5 company/source tests, then governed 500-universe ingestion, then research consumers. Independent feature flags default OFF; rollback disables proposed routes rather than deleting data; original price workers remain untouched.

**Rejected:** One PR activating all providers, 17 proposed tables, a scheduler and 500-company backfill at once.

## ADR-013 — Dedicated planned architecture version
**Selected:** `DB-ARCH-2.0` lives under `docs/database/planned/DB-ARCH-2.0/` with `status: PLANNED`, `production_status: NOT_DEPLOYED`, and separate review/promotion. Production remains `DB-ARCH-1.0`; `docs/database/CURRENT.yaml` is unchanged.

**Rejected:** Editing `docs/database/current` or the production contract to add hypothetical tables before deployment.

## ADR-014 — Strict account and automation boundaries
**Selected:** No automated securities trades, no alterations to Google Sheet `Transactions`, holdings quantities, cost basis, manual override or Dashboard valuation logic. No continuous research job, reminder or monitoring schedule is created by this design. If future jobs are explicitly authorized, their creation requires separate scheduling, credentials and budget gates.

**Rejected:** Assuming approval of architecture design includes background execution, production-as-test provider calls or automatic trading.

## ADR-015 — Unresolved E2E gates must not be borrowed
**Selected:** Keep first natural Crypto Cron #20 post-rename receipt and Twelve-only #17→#18 post-retirement Stock readback as independent `PENDING_SCHEDULED_RUN`. Retain GitHub Issue #106 OPEN until real autonomous evidence exists. Neither price E2E acceptance nor any future Research E2E can be manufactured from unit tests or documentation.

## Open design-review questions (not approval blockers for documentation)

1. What licensed, source-backed current and historical S&P 500 membership feed should FWIOS use? Is current-universe-only screening acceptable until historical rights are obtained?
2. What is the minimum required point-in-time Fundamentals field set, and which SEC exceptions/custom tags are in scope for the first 3–5 companies?
3. Is a paid Massive Fundamentals subscription justified after a sample entitlement/coverage assessment, or can SEC-first satisfy the pilot?
4. Should a future research scheduler be event-driven, nightly or operator-triggered? No schedule is approved yet.
5. Which raw payloads may be stored under each vendor's license, and what restrictions apply to personal-use vs future customer-facing deployment?
6. Is the 17-table candidate larger than necessary for an approved MVP? The phase gates explicitly permit deferral and reduction **before** first migration.

All decisions remain proposals until the architecture is reviewed; **no implementation is authorized**.
