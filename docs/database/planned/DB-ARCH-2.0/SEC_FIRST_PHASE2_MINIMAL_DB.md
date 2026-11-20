# SEC-first Research MVP — Phase 2 evidence audit and minimal DB design

**Review date:** 2026-11-11 (Asia/Bangkok). **STATUS:** DESIGN / OFFLINE STATIC TESTS ONLY; **NOT DEPLOYED**. This is an evidence-first continuation of PR #132 at `main` SHA `cca62eb295a6d4c08d3dd9cebe119c6e57d1b4b6`. It does **not** install a research database, prove production availability, authorize spending, enable trading or change a price route.

## 0. Read-only baseline (verified 2026-11-11 ~03:17–03:19 UTC)

- GitHub source: `contracts/system-contract.yaml` is still `ASSET-PRICE-CONTRACT-1.1.0` and `auto_trade=false`. `docs/database/CURRENT.yaml` still selects `DB-ARCH-1.0`; `DB-ARCH-2.0` is planned. The Phase-1 offline-only SEC parser is `research/sec_first_mvp/core.py` with contract `contracts/sec-first-research-mvp-v0.yaml`.
- Supabase project `ysjbmeukwbfnxnwqchuq` was `ACTIVE_HEALTHY` (PostgreSQL 17.6). Live schema inventory: `fwios.instruments`, `fwios.instrument_symbols`, `fwios.market_observations`; `fwios_quota.api_call_ledger`. No `fwios_research` or `fwios_provider` schemas or tables. `fwios.market_observations` read-only count: **1,190**; BEFORE UPDATE and BEFORE DELETE append-only guard confirmed.
- Live migrations end at `20261109045146`; six active Crons #15–#20; two ACTIVE Edge Functions: `price-market-refresh-v1` v14 and `price-sheet-sync-v1` v7. None were invoked.
- Live ACL check: `anon` and `authenticated` lacked USAGE on `fwios` and `fwios_quota`, and had no table SELECT/INSERT on inspected price/quota tables. `fwios_quota.api_call_ledger` has RLS **disabled**; connector table inventory raised a generic warning, but direct grants do not substantiate public exposure. A separate risk review of Data API exposed-schema configuration, grant inheritance and privileged RPC execution remains necessary; **no production remediation was applied**.
- SEC-first Research Phase-2 work is not another Stock EOD cutover. Issue #106 is closed with natural Twelve-only 4/4 + Sheet follow-up E2E evidence; no retest or manual dispatch.
- Referenced handover basename `FWIOS_HANDOVER_2026-11-11.md` was not present in the accessible attached conversation/Library search or `main` tree during this session. The checked live sources and recorded limitations above therefore take precedence; do not claim the missing handover was read.

## 1. Real SEC primary-document pilot (4 issuers)

All samples are **source-discovery/filing verification**, not raw Company Facts parser E2E. The SEC HTML filings/indexes below were reachable via public search results; direct `data.sec.gov/submissions` and `companyfacts` JSON retrieval was unavailable through the research interface. There is **no** real Company Facts checksum, batch ingestion receipt, first-FWIOS-observed timestamp, or tested JSON-row count. Do not invent those fields.

| Ticker / CIK | SEC accession, filing and period | Evidence | Observed face-statement example, **not** parsed/tag-certified |
|---|---|---|---|
| MSFT / `0000789019` | `0001193125-26-436133`; 10-Q filed **2026-10-28**; period **2026-09-30**; SEC index accepted **2026-10-28 16:07:39** (SEC index local clock, timezone not normalized) | [SEC index](https://www.sec.gov/Archives/edgar/data/789019/000119312526436133/0001193125-26-436133-index.htm), [10-Q](https://www.sec.gov/Archives/edgar/data/789019/000119312526436133/msft-20260930.htm) | Quarter revenue **$92,279 million** |
| NVDA / `0001045810` | `0001045810-26-000075`; 10-Q filed **2026-08-26**; period **2026-07-26**; SEC index accepted **2026-08-26 16:36:00** (timezone unnormalized) | [SEC index](https://www.sec.gov/Archives/edgar/data/1045810/000104581026000075/0001045810-26-000075-index.htm), [10-Q](https://www.sec.gov/Archives/edgar/data/1045810/000104581026000075/nvda-20260726.htm) | Quarter revenue **$96,221 million** |
| TTWO / `0000946581` | `0001628280-26-072254`; 10-Q period **2026-09-30**; **2026-11-09** filing date from third-party index; exact SEC index acceptance **not independently confirmed** | [SEC 10-Q](https://www.sec.gov/Archives/edgar/data/946581/000162828026072254/ttwo-20260930.htm) | Quarter net revenue **$1,497.0 million** |
| TLN / `0001622536` | `0001622536-26-000086`; 10-Q filed **2026-11-03**; period **2026-09-30**; SEC index accepted **2026-11-03 09:00:03** (timezone unnormalized) | [SEC index](https://www.sec.gov/Archives/edgar/data/1622536/000162253626000086/0001622536-26-000086-index.htm), [10-Q](https://www.sec.gov/Archives/edgar/data/1622536/000162253626000086/tln-20260930.htm) | Financial statement is present; one tagged USD metric has **not** been independently reconciled |

**These prices/revenues are not investments signals.** The three numeric examples are human-readable financial statement amounts (USD millions), NOT demonstrated `us-gaap` Company Facts XBRL tags or normalized stored facts. `Net revenue` text does not automatically equal a chosen SEC `Revenues` tag. Further check concept, unit, instant/duration period, context, issuer, submission filing and amendment before acceptance.

### Data quality / provenance / as-of gates

| Gate | Verified result | Status |
|---|---|---|
| Official SEC source document located, matching selected issuer | 4/4 10-Q pages | SOURCE_LOCATED |
| SEC index accession + filing date + acceptance clock directly confirmed | 3/4 (TTWO index acceptance pending direct SEC proof) | PARTIAL |
| At least one face-statement value publicly visible | 3/4 documented above; not XBRL-tagged | HUMAN_REVIEW_ONLY |
| Real `submissions` + `companyfacts` JSON downloads with checksums | 0/4 | NOT_RUN |
| Phase-1 parser run on 4 genuine SEC JSON pairs | 0/4 | NOT_RUN |
| `first_seen_at` provenance generated by FWIOS ingest | 0/4 | UNKNOWN |
| SEC `first_public_at` independently proven | 0/4 | UNKNOWN |
| Accepted historical point-in-time/backtest facts | 0/4 | **NOT_CERTIFIED** |

SEC EDGAR `accepted_at`, filing date and fiscal period **must not be substituted** for `first_public_at`. A hypothetical historical decision at time `T` must block a fact if earliest safely known `first_seen_at > T`, if source accepted after `T`, or if independent first-public evidence required for backtest certification is unknown. Later corrections/amendments must create new versions and not backdate prior beliefs. For current research, source observation and SEC filing acceptance are independent gates. SEC source rules: [EDGAR APIs](https://www.sec.gov/search-filings/edgar-application-programming-interfaces) and [Fair Access](https://www.sec.gov/about/developer-resources); automated SEC collection requires a genuine contact-bearing User-Agent and <=10 req/s overall. No identifying User-Agent or live API calls were fabricated for this pilot.

## 2. Minimal database: FIVE tables, issuer-level only

Proposed **non-migration** SQL reference: `research/sec_first_mvp/phase2_minimal_schema.sql`. This deliberately selects five of the planned research tables in `DB-ARCH-2.0/TABLE_CATALOG.md`, rather than implementing all 11 research + 6 provider tables.

1. `ingest_batches`: CIK, observed/retrieval time, decision as-of, bounded sample counts, truncated/status flag, always `historical_asof_certified=false`.
2. `raw_evidence`: batch FK, `SUBMISSIONS`/`COMPANYFACTS` origin, SEC URL, canonical response hash, retrieval UTC, optional *private* object pointer (default hash-only rights).
3. `sec_filings`: accession PK, issuer CIK, form, filed and SEC accepted clocks, optional amendment link, submissions evidence FK.
4. `metric_facts`: accession+CIK FK, company-facts evidence FK, `us-gaap`, USD, concept, period, numeric value, first seen, **nullable** first-public time, unique immutable fingerprint. Original and amended accessions remain distinct.
5. `validation_results`: evidence/batch, optional accepted fact FK, source subject hash, validator version, immutable intended verdict and reason codes. Quarantine must remain visible.

These are **issuer filing facts, not tradable securities**. No `security_master`, dated ticker alias, index membership, provider registry, EOD bars, news, portfolio ledger or bridge are created by this minimal pilot. Security-to-CIK mapping is a later separate review, not implicit via `fwios.instruments`.

**Schema design caveat:** DDL is not deployed or PostgreSQL-integration-tested. Even if syntactically accepted, source/CIK consistency across FKs, unit/period tag semantics, access-control roles, unique same-batch acceptance and physical append-only triggers require separate executable tests and review. Enabling RLS alone is not proof of least privilege. Planned private schema must stay outside exposed Data API schemas, with explicit denied client grants, server principal allowlist, and strictly limited routine EXECUTE. Raw persistence requires legal-rights review. No new Vault keys.

## 3. Test and acceptance matrix

**Committed offline static guards** (`tests/research/test_phase2_schema_design.py`): 10 checks for non-migration scope, exactly five research tables, RLS on all, revoked client rights, filing/provenance FKs, CIK issuer identity, nullable first-public, bounded 500-row recent-only scope, no protected-domain DDL, and explicitly absent append-only/isolated-DB controls. Run with existing `python -m unittest discover -s tests/research -p 'test_*.py' -v`; this suite performs **no provider or database calls**.

**Required later isolated PostgreSQL tests (NOT RUN):**

| Case | Acceptance |
|---|---|
| P2-DB-01 Privileges/API | `anon`/`authenticated` cannot USAGE, SELECT, INSERT or call elevated RPC; server role limited; exposed schemas checked |
| P2-DB-02 Replay | same accession+fact fingerprint cannot duplicate; conflicting versions are quarantined, not overwritten |
| P2-DB-03 Referential lineage | no fact without valid same-CIK filing/accepted source + companyfacts receipt |
| P2-DB-04 Append-only | UPDATE/DELETE on facts, evidence and validation receipts blocked for normal worker role |
| P2-DB-05 As-of | fact with first seen after `T`, accepted after `T`, or unknown public-time backtest evidence cannot pass historical certification |
| P2-DB-06 Amendment | original and `10-Q/A` accession versions both remain readable with separate proof |
| P2-DB-07 Tamper/bad data | wrong CIK, malformed period, unsupported unit/tag, future acceptance, hash mismatch quarantined |
| P2-DB-08 DB isolation | pre/post count/hash/schedule/worker comparison proves zero writes to protected price/portfolio domains |
| P2-DB-09 Recovery | preflight backup + feature-gate disable + restore replay tested in nonproduction |

**Required real-provider evidence pilot (NOT RUN):** obtain official SEC JSON pairs via *explicit* manual fetch with genuine operator contact User-Agent; record HTTP source response as-observed time, canonical SHA-256 of both payloads, 3–5 CIKs, CIK/accession join, accepted/quarantined/truncated counts per issuer. Keep raw local output permission 0600, record duplicate detection, never assert full historical completeness due recent-array limitation. Operator must approve any private retention or external request budget constraints separately.

## 4. Rollback / promotion controls

**Now (design only):** revert/close this GitHub draft branch or PR. No Supabase migration, Edge deployment, Cron or Google Sheet write exists to undo. Production price and portfolio state remain authoritative.

**Hypothetical future isolated private database (requires separate written authorization):**
1. Before applying guarded migration, snapshot privileges, schema inventory, migration head, worker versions, six Cron definitions, price observation counts/checksums and quota audit; back up research pilot evidence based on retention rights.
2. Feature-flag all research writes/reads **OFF by default**. No Cron or provider gateway initially. If test fails, disable all research routes and revoke the dedicated research worker's grants. Do not revert or touch the current price worker.
3. Preserve append-only evidence and validation outcomes in secure storage. Restore only the **isolated** schema from tested snapshot if required, with explicit authorization. Never destructive blanket `CASCADE`, never delete canonical price history.
4. Pass ACL, leakage, append-only, FK, parser, as-of and rollback tests in disposable PostgreSQL before any production proposal; record pre/post differences.
5. Only separately authorized production rollout can change `docs/database/CURRENT.yaml`, and only after deployment and live postflight. Preserve `DB-ARCH-1.0` as current until then.

## 5. Findings requiring a later decision

- Real SEC JSON parser execution is **unverified** for all four issuer samples; this is not 4/4 data-ingestion PASS.
- TTWO exact SEC index acceptance evidence needs confirmation, and all sample acceptance clocks need explicitly sourced timezone semantics before storing `timestamptz`.
- Actual 3–5 real-company success/failure distribution, company-specific missing concepts, amendments, source hashes and honest `first_seen_at` still require live fetch under SEC fair-access rules.
- Proposed DB ACL/trigger/physical design is **not deployable yet**. Provide an isolated disposable DB harness and separate migration/retention authorization only after review.
- Do not restart Issue #106, revive Alpha Vantage, extend price-service stock universe or enable automatic trading.
