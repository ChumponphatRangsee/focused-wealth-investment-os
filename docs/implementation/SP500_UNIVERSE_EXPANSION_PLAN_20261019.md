# S&P 500 Universe Expansion Plan — 2026-10-19

## Goal

Expand FWIOS from the current 64 ACTIVE Stock instruments toward current S&P 500 security coverage without turning Phase 1 into a full-universe AI research system.

Target architecture:

`S&P 500 Membership -> Canonical Identity -> Cheap EOD Price Coverage -> Scanner Visibility -> Candidate Promotion -> Selective Research / Valuation -> Full Scanner Score`

The broad universe is for discovery. Deep research remains scarce and selective.

## Current Starting Point

Verified on 2026-10-19:

- 64 ACTIVE Stock instruments;
- 6 ACTIVE Crypto instruments;
- `fwios.v_scanner_current_v1` returns 64 stocks;
- 27 currently have full Scanner Score;
- non-researched names can remain visible as `PRICE_ONLY`;
- Focused Wealth Dashboard is portfolio-independent;
- Supabase is authority and Google Sheet is presentation;
- existing cache / quota / scheduler / canonical identity infrastructure must be reused;
- `auto_trade=false`; human execution only.

## Important Index Modeling Detail

Do not model S&P 500 as exactly 500 ticker rows.

The index targets roughly 500 companies but can contain more security lines because multiple share classes can be constituents. The membership model therefore operates at the canonical security/instrument level.

The live count is data, not a contract constant.

## Source Policy

### Tier A — Authoritative

Preferred source:

- S&P Dow Jones Indices licensed constituent / pro-forma / corporate-event data;
- S&P DJI official constituent-change announcements and index methodology.

Store source lineage and effective dates for every membership change.

### Tier B — Operational Proxy

When a licensed full constituent feed is not available, a tracker such as State Street SPDR S&P 500 ETF Trust daily holdings may be used only as an operational discovery/reconciliation source.

Rules:

- mark rows/source receipts as `TRACKER_PROXY`;
- never label proxy membership as S&P-authoritative;
- reconcile additions/removals against S&P DJI announcements;
- do not silently overwrite an authoritative effective-dated membership record from proxy data.

### Source Precedence

`OFFICIAL_LICENSED > OFFICIAL_ANNOUNCEMENT > TRACKER_PROXY > MANUAL_VERIFIED`

Conflicting lower-tier data is quarantined for review rather than overwriting higher-tier membership.

## Minimal Data Model

Keep Phase 1 small.

### 1. `fwios.index_constituent_sync_runs`

One row per ingestion attempt.

Suggested fields:

- `run_id`
- `index_code` = `SP500`
- `source_class`
- `source_name`
- `source_as_of`
- `retrieved_at`
- `row_count_raw`
- `row_count_resolved`
- `row_count_unresolved`
- `added_count`
- `removed_count`
- `changed_count`
- `status` = `PASS | REVIEW | BLOCKED`
- `source_fingerprint`
- `notes`

Do not store credentials.

### 2. `fwios.index_constituent_membership`

Effective-dated membership by canonical instrument.

Suggested fields:

- `index_code`
- `instrument_id`
- `asset_symbol_at_event`
- `company_name_at_event`
- `sector_at_event`
- `announcement_date`
- `effective_from`
- `effective_to`
- `membership_status`
- `source_class`
- `source_run_id`
- `provenance_status`
- timestamps

Key invariant:

A constituent removal closes the membership interval; do not delete history.

### 3. `fwios.v_sp500_universe_current_v1`

Current security-level universe joined to canonical identity.

Expose:

- canonical symbol
- company
- sector
- membership effective date
- source class / provenance
- identity resolution status
- pricing eligibility
- scanner eligibility

This view becomes the universe gate for broad S&P 500 stock coverage.

## Canonical Identity Rules

Membership ingestion must resolve into the existing canonical instrument identity layer.

Handle explicitly:

- ticker changes;
- share classes;
- mergers/acquisitions;
- spin-offs;
- delistings;
- symbols containing punctuation;
- provider-specific aliases;
- company rename without security change.

Never create duplicate instruments merely because a source formats a ticker differently.

Unresolved symbols go to a review queue and do not silently become production scanner rows.

## Membership Lifecycle

Recommended states:

- `ANNOUNCED_ADD`
- `ACTIVE`
- `ANNOUNCED_REMOVE`
- `REMOVED`
- `IDENTITY_REVIEW`

Rules:

1. An announced addition may be stored before its effective date.
2. It becomes `ACTIVE` only at the effective boundary.
3. An announced removal remains active until its removal becomes effective.
4. Historical membership remains queryable.
5. Corporate-action exceptions can take effect between regular review dates.
6. Current count is derived from effective-dated rows, never hard-coded.

## Ingestion Cadence

### Membership

Cheap daily check is acceptable because it does not consume market-data quota.

Recommended:

- one daily source check on U.S. business days;
- event-driven/manual recheck when an official S&P constituent announcement is detected;
- one stronger reconciliation around scheduled index review/rebalance windows.

Do not rebuild all canonical identities on every run. Diff the source snapshot against current membership.

### Market Data

Use the existing FWIOS Market Data Service.

For active S&P 500 constituents:

1. cache check;
2. freshness check;
3. distributed single-flight;
4. quota check / reservation;
5. batch/provider call;
6. observation + provenance write;
7. daily-close canonicalization.

No direct Google Sheets market-data calls.

## Price Ingestion Budget

Do not issue ~500 independent expensive provider calls by default.

Required behavior:

- prefer provider batch/bulk EOD endpoints when available;
- group requests according to the provider policy already registered in FWIOS;
- use one canonical close per security/session;
- skip symbols whose required session is already cached;
- retry only missing/failed symbols, not the full universe;
- isolate provider failures so one bad ticker does not block all rows;
- assign broad-universe work lower priority than held-asset pricing.

Existing held positions keep priority over broad scanner refresh.

The scanner may show stale/missing-price states rather than exhausting emergency quota.

## Coverage States

Broad universe coverage is intentionally progressive.

### `PRICE_ONLY`

Has:
- canonical identity;
- active index membership;
- canonical market price.

Does not require research or valuation.

### `NO_VALUATION`

Use when identity/research metadata may exist but no valid current valuation exists.

### `VALUATION_ONLY`

Has usable valuation but insufficient core research inputs for Scanner Score.

### `SCORED`

Has all required deterministic inputs for the current Scanner Score.

### `PRICE_BLOCKED`

Price is missing, stale beyond policy, conflicting, or provenance-failed.

Do not fabricate a rank.

## Broad Scanner Behavior

The user-facing table may contain the full current membership even when only a minority is deeply researched.

Rules:

- every eligible constituent can appear with price / sector / coverage state;
- rank is nullable;
- `PRICE_ONLY` rows remain visible and unranked;
- full Scanner Score remains deterministic and uses the existing portfolio-independent formula;
- current holdings never increase rank or research priority automatically;
- no portfolio fit / account / position sizing / cash / P&L columns enter the broad scanner.

## Selective Research Funnel

Do not AI-research every constituent daily.

Use a two-stage funnel.

### Stage 1 — Cheap Broad Discovery

Inputs should be limited to already-available or inexpensive deterministic data, for example:

- canonical price / daily close;
- sector;
- existing valuation/research coverage flags;
- cached research freshness;
- simple price-dislocation or coverage signals where supported by existing data.

Output:

- `NO_ACTION`
- `RESEARCH_CANDIDATE`
- `REFRESH_EXISTING_RESEARCH`

This stage must not invent a full investment thesis.

### Stage 2 — Selective Deep Work

Only a bounded candidate queue receives:

- deeper fundamentals/evidence;
- thesis creation/update;
- valuation;
- quality/downside review;
- full scanner scoring eligibility.

Recommended Phase-1 cap:

- research only a small candidate batch per cycle;
- cap must be driven by current quota/cost policy rather than a fixed ~500-symbol target;
- stale existing high-value research can compete with new candidates for the same budget.

## Research Prioritization

Candidate priority should prefer decision value, not index weight alone.

Possible deterministic priority components:

- missing research on a materially dislocated price;
- stale valuation on a previously high-quality company;
- high-quality prior thesis with large new price movement;
- newly added constituent with meaningful discovery signal;
- explicit user-requested ticker.

Current portfolio ownership must not be part of the Scanner Score.

Portfolio-aware research priority, if ever used elsewhere, must remain a separate controller concern and must not contaminate this read model.

## Scanner Read Model Evolution

Do not replace `v_scanner_current_v1` abruptly.

Recommended sequence:

1. add `v_sp500_universe_current_v1`;
2. prove identity + membership counts;
3. extend scanner universe source from current active stock universe to active S&P membership;
4. preserve existing research/valuation joins;
5. keep nullable score/rank;
6. regression-test the original 64 symbols against pre-expansion results;
7. expose expanded rows in Sheet only after parity passes.

The current 64 researched/priced names should not change score merely because the universe becomes larger.

Ranks among scored names may change only if newly scored names are introduced, not because `PRICE_ONLY` names exist.

## Google Sheet Changes

Do not add 500-row business logic to Sheets.

Sheet remains presentation only.

`_Scanner_Data` should receive the expanded backend read model.

User-facing `S&P500 Scanner` should show:

- actual current coverage count;
- scored count;
- price-only count;
- no-valuation count;
- latest session;
- explicit source/coverage note.

Avoid claiming complete S&P 500 coverage until membership reconciliation passes.

`Valuation Map` should continue showing only names with valid valuation coverage.

## Scheduling

Separate schedules:

### Membership Sync
Low-cost, daily or announcement-triggered.

### Broad EOD Price Coverage
Once per eligible U.S. session after close, quota-aware.

### Deep Research Refresh
Bounded, lower-frequency, candidate-driven.

Do not tie deep research execution to every price refresh.

## Acceptance Gates

### Gate A — Membership

PASS when:

- source run is traceable;
- all active source securities are resolved or explicitly quarantined;
- no duplicate active canonical security membership;
- additions/removals preserve effective dates;
- active count is plausible and not hard-coded.

### Gate B — Identity

PASS when:

- every production-eligible membership maps to canonical instrument identity;
- share classes remain distinct where appropriate;
- alias mapping does not create duplicates.

### Gate C — Pricing

PASS when:

- expected active constituents are represented;
- current eligible U.S. session coverage meets the agreed threshold;
- missing rows are explicit;
- cache/quota records reconcile;
- held-asset pricing remains unaffected.

Do not require 100% provider success to publish the scanner; publish explicit `PRICE_BLOCKED` rows and alert on coverage degradation.

### Gate D — Scanner Regression

PASS when:

- existing 64-symbol price/valuation/research values preserve parity;
- score formula remains unchanged;
- score/rank is null when inputs are insufficient;
- no portfolio-dependent columns leak into the read model;
- no formula errors in Scanner / Valuation Map.

### Gate E — Cost / Quota

PASS when:

- broad price refresh fits normal provider budget;
- no emergency reserve is consumed by background scanner work;
- deep research is bounded;
- retries are targeted;
- cache hit behavior is verified.

## Rollout Phases

### Phase U1 — Membership Foundation

- create membership + sync-run tables;
- create current membership view;
- build one source adapter;
- ingest current membership;
- resolve identity;
- no scanner UI change yet.

### Phase U2 — Broad EOD Pricing

- enqueue active current constituents;
- use existing quota/cache scheduler;
- verify provider batching and cost;
- measure coverage and failure modes.

### Phase U3 — Scanner Expansion

- extend scanner universe to current S&P membership;
- preserve nullable score/rank;
- expose `PRICE_ONLY` / `NO_VALUATION`;
- regression-test original 64 names.

### Phase U4 — Selective Research Queue

- add deterministic candidate promotion;
- cap deep research work;
- add valuation/research coverage metrics;
- never force full research coverage.

### Phase U5 — Lifecycle Automation

- daily membership diff;
- announced additions/removals;
- effective-date transitions;
- identity aliases / corporate-action handling;
- audit receipts and alerts.

## Non-Goals

Phase 1 does not require:

- full deep research for every constituent;
- daily AI analysis of ~500 companies;
- full valuation coverage;
- real-time intraday pricing for the broad scanner;
- portfolio optimization across the index;
- automatic order execution;
- a second accounting ledger.

## Safety Invariants

- Supabase remains authority.
- Google Sheet remains presentation.
- Investment Portfolio Tracker remains portfolio accounting authority.
- Focused Wealth Dashboard remains portfolio-independent.
- held-asset market data has priority over background scanner work.
- no transaction/cost basis/cash/quantity/P&L mutation.
- `auto_trade=false`.
- `human_execution_only=true`.

## Recommended Next Implementation

Start only **Phase U1 — Membership Foundation**.

Do not change the scanner UI in the first PR.

Deliverables for U1:

1. migration for the two minimal membership tables;
2. `v_sp500_universe_current_v1`;
3. one source adapter with source-class provenance;
4. current snapshot ingestion;
5. identity-resolution report;
6. membership count / duplicate / interval regressions;
7. no changes to portfolio or execution paths.

After U1 is verified, inspect existing provider quota capacity before approving U2 broad-price ingestion.
