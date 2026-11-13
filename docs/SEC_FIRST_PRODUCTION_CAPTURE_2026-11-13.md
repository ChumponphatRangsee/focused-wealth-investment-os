# Production SEC-primary JSON capture — 2026-11-13

**Status: LIVE ONE-SHOT CAPTURE COMPLETE 8/8; RESEARCH PARSER/PIT NOT CERTIFIED.**
Approval: user explicitly approved one-time SEC-first work on the Production Supabase project and supplied an operator contact for SEC Fair Access. **The operator email is not committed here, stored in research data or reproduced in this report.**

## Contract and scope
- Source: SEC `data.sec.gov`, Submissions + Company Facts, known CIKs for MSFT, NVDA, TTWO, TLN.
- One-time GET from Supabase `pg_net`, fixed endpoints, operator-identifying HTTP User-Agent, `Accept: application/json`, `Accept-Encoding: identity`. Exactly 8 request IDs `12073..12080`; no retries, scheduler or automatic research fetcher created.
- Production migration `20261113025052_sec_primary_json_capture_v1` created **only** private `fwios_research.sec_primary_json_captures_v1` plus an UPDATE/DELETE blocking trigger. No changes to `fwios`, `fwios_quota`, existing Edge Functions, Crons or accounting.
- This additive evidence-receipt pilot is **NOT** deployment of all DB-ARCH-2.0 tables. Current Price Service remains `ASSET-PRICE-CONTRACT-1.1.0` and Google Sheet accounting remains authoritative. `auto_trade=false`.

## Eight verified primary-source receipts (from the durable database, not transient HTTP cache)
| Ticker | Source | Request ID | Bytes | SHA-256 of UTF-8 response body | Received at UTC |
|---|---|---:|---:|---|---|
| MSFT | submissions | 12073 | 186,640 | `4d4ff98b1deea7b90123e2b99c059cdac4343de0dccbdfdc9855e788419f893e` | 2026-11-13T02:44:18.374224Z |
| MSFT | companyfacts | 12074 | 4,938,072 | `8c1903c041f5c27e86ed15f37debb1f41882b7904bba129ef9edc76478b1e8ea` | 2026-11-13T02:46:29.924428Z |
| NVDA | submissions | 12075 | 160,083 | `092e307ba8b409e49bd89a410eeb3134e7d193ea083eaf6e687539702b2ede07` | 2026-11-13T02:47:19.919641Z |
| NVDA | companyfacts | 12076 | 4,092,966 | `19ef503a5770f5660964b3c3aea6937579d9b359da344afe6a9adf59c63d26ff` | 2026-11-13T02:47:24.667247Z |
| TTWO | submissions | 12077 | 157,609 | `d04e462f69526b8010ed80e027604c0a8bc0364879a20b411b7e1a41303a88f8` | 2026-11-13T02:47:28.528337Z |
| TTWO | companyfacts | 12078 | 3,358,400 | `cd0eb49c1e2ec26a189ea7d7b14fd93d1480548f2600ab2084b2afda47419409` | 2026-11-13T02:47:32.594653Z |
| TLN | submissions | 12079 | 71,493 | `3c1c03da04f81ab4bfca685f3411c9892cd93af7e175671a4ae252405d683307` | 2026-11-13T02:47:36.729231Z |
| TLN | companyfacts | 12080 | 1,330,332 | `862806255a15c5a61e67a1575e462a87a9c5fb0288bf2733ee0df9e517dd7154` | 2026-11-13T02:47:40.434280Z |

**Total:** 8 documents, 14,295,595 UTF-8 bytes, four CIKs. Each record has provider URL, source `cik`, request ID, response code (200), source-receipt time and raw UTF-8 body SHA-256. A receipt's `response_recorded_at` is the time `pg_net` recorded the completed HTTP response; it is **not** historical SEC `first_public_at`.

**Hash semantics:** `sha256_body_utf8` = lowercase hex of Postgres `sha256(convert_to(raw_body_utf8, 'UTF8'))`. The original SEC JSON response was requested with identity content encoding and parsed into UTF-8 text by `pg_net`; this receipt hash protects the stored exact UTF-8 response representation, not HTTP wire headers or transport framing. The Python Phase-1 canonical JSON SHA algorithm is distinct and has not yet been run on these captured payloads.

## Real production postflight
- Durable table count **8**, unique request IDs **8**, distinct CIK/company count **4**.
- Recalculated SHA-256 from **persisted** UTF-8 text **8/8 matches**.
- Reparsed persisted JSON, matching `issuer_cik` **8/8**, validating recent Submissions object / US-GAAP Company Facts object **8/8**.
- All eight have `first_public_at=NULL` and `historical_asof_certified=false`; no false PIT or backtest assertion.
- Private research schema: RLS enabled, direct schema USAGE/SELECT denied for `anon`, `authenticated` and `service_role`; `deny_sec_capture_update_delete` BEFORE triggers exist for both UPDATE and DELETE.
- Existing price tables remain: `fwios.market_observations` **1,212 rows before and after**, `fwios_quota.api_call_ledger` **44**; six active Crons #15–#20; `price-market-refresh-v1` v14 and `price-sheet-sync-v1` v7 unchanged. Existing historical quota ledger RLS advisory is unrelated; no production permission change applied.
- No Google Sheet, broker, price/FX observation, market-price eligibility, Portfolio Accounting or trading mutation was performed. Issue #106 was not repeated.

## Remaining validation (NOT RUN)
1. Run the existing Phase-1 Python `build_evidence` on genuine paired JSON, using each company's **later** Submissions/Company Facts retrieval time as conservative `first_seen_at`; record accepted/quarantined/truncated counts, concept/tag/unit/period and accession mapping. Existing parser only certifies current observed research; no historical PIT.
2. Validate accession and SEC accepted time from Submissions and later primary-file evidence; `first_public_at` remains unproven and cannot be inferred from fiscal period end or filing acceptance.
3. If a future application must read these stored records, review a dedicated least-privilege server-role policy or explicit operator-only export. This one-time capture grants no client-facing query access.
4. Review private research persistence retention and operational backup. `net._http_response` has a six-hour default TTL, but these captured rows persist in PostgreSQL independently.

## Rollback and recovery
- **Immediate containment:** no automated collector, scheduled job or consumer exists; research schema is closed to client roles by default. No SEC capture request or credential remains in a new Worker/Cron.
- **No destructive rollback by default:** preserve eight immutable receipts while lineage is reviewed. If explicit later approval requires decommissioning, export/verify all eight hashes and a recoverable private backup first, then use a targeted migration that does **not** touch `fwios`, `fwios_quota`, protected price Crons/Workers or accounting.
- Source of truth is the live migration and stored database receipts; GitHub source mirror is for review/traceability. Never merge this as permission to turn on trading, broad provider routing or research scheduling.
