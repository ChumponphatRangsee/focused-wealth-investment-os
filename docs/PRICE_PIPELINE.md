# Price Pipeline & Operations — v1.0.0

**Scope:** Crypto USD/THB FX observations, Supabase storage and Google Sheet synchronization only. No stock ingest, scanner, research, valuation, trading or future roadmap. `auto_trade=false`.

```text
Google Sheet Holdings (OPEN Crypto symbols; read-only)
     ├── CoinGecko native USD quotes
     └── Frankfurter USD/THB FX
                 ↓
Supabase fwios.market_observations
                 ↓
price-sheet-sync-v1
                 ↓
Google Sheet _Market_Data (Crypto rows + FX only)
                 ↓
Price Data / Holdings formulas
```

### Active schedule

| Job | Mode | Worker |
| --- | --- | --- |
| #14 | CRYPTO, 6 supported assets | `price-market-refresh-v1` v2 |
| #15 | USD/THB FX | `price-market-refresh-v1` v2 |
| #16 | Sheet write + readback | `price-sheet-sync-v1` v2 |

Job names inherited from the old system are misleading. Verify their *commands*. Scheduled cycle on 2026-10-30 04:10/04:20 Bangkok returned HTTP 200 and persisted / read back the current prices.

### Invariants

- Asset list: OPEN Crypto symbols from Sheet Holdings (read-only), supported BTC/DOGE/ETH/HBAR/SOL/XRP only. No portfolio quantities or transactions are persisted in Supabase.
- CoinGecko positive native USD quotes, provider timestamp no more than 2 hours old.
- Frankfurter USD/THB positive rate, source date no more than 5 days old; THB conversions remain spreadsheet formulas.
- Store source, provider, timestamps, session date and provenance via `fwios.ensure_market_observation_v1`. Read quotes via `fwios.pr7_native_usd_price_read_v1` and `fwios.pr5_native_usd_price_shadow_v1`.
- Vault-backed automation token; HTTP header authentication, not URL parameter. Never commit tokens or credentials.
- Sheet sync updates only the six Crypto prices plus FX; protects existing four frozen stock prices, quantities, transactions, manual overrides, cost-basis and formulas. Readback must pass; no Portfolio writes. `auto_trade=false`.

### Current production schema

`fwios` contains only the tables `asset_entities`, `instruments`, `instrument_symbols`, `instrument_identifiers`, `market_observations`; one `v_instrument_identity_current` view, six SQL functions. The 87-table historical `fwios_legacy_archive_20261029` was **permanently dropped by user action without backup** on 2026-10-30. Seven now-orphaned SQL functions were removed via an applied migration. Do not refer to archived data as available.

Only three Cron registrations remain active. Two supported Edge deployments remain. Sixteen retired ones still serve inert HTTP 410 and require Dashboard/CLI physical deletion.

### Verification receipts

Natural scheduled 2026-10-30 cycle: HTTP 200 for CRYPTO (#11970), FX (#11971), Sheet (#11972). After permanent archival deletion and routine cleanup: direct CRYPTO (#11978) HTTP 200 6/6; FX (#11979) HTTP 200 one observation; Sheet (#11980) HTTP 200 with six Crypto/FX readback PASS and zero Portfolio/DB accounting writes. Updated read-only production SQL regression 27/27 PASS.

When diagnosing future schedules, inspect `cron.job_run_details` and **actual** `net._http_response` statuses, observation timestamp/provenance, and Sheet readback. Cron `succeeded` alone does not establish successful HTTP response.
