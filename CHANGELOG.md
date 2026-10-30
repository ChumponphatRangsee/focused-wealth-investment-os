# Changelog — Asset Price Data Service

## 2026-10-30 — Three-table price identity consolidation (Production applied)

- Removed two redundant FWIOS price-identity tables: `asset_entities` and `instrument_identifiers`; preserved all 70 entity attributes under `instruments.metadata.retired_entity` and continued the original 70 instrument UUIDs/symbol mappings.
- Replaced the identity view's entity join with `instruments.metadata` projection, retaining existing columns and names. `market_observations` retained, no canonical price records rekeyed or deleted.
- Production now **3 tables, 1 view, 6 SQL routines, 5 Crons**. Live SQL regression **36/36 PASS**; post-cleanup Crypto/FX writes and `_Market_Data` Sheet readback all HTTP 200 with zero portfolio mutations.
- US Stock EOD API quota still limits fresh close collection; 16 inactive Legacy Edge deployments still pending physical deletion.


## 1.1.0 — 2026-10-30: Daily US Stock EOD deployed and scheduled (first quote pending)

- Add Alpha Vantage daily unadjusted close to the two supported price-only workers for OPEN Stock symbols from Google Sheet. Four held symbols initially: MSFT, NVDA, TLN, TTWO.
- Strict current NY trading-date verification, provider identity, positive prices, secret-safe provenance, atomic observation persistence and read-only holdings.
- Sheet worker syncs only newly certified Stock EOD observations, preserving all non-eligible historical stock rows and all crypto/FX/holdings protections.
- Installed Cron #17 at 19:00 ET and #18 at 19:30 ET on weekdays with a DST-aware New York clock, retaining existing jobs #14–#16.
- **Stock quote success remains unverified:** Alpha Vantage dry run returned daily quota limit (HTTP 503, #11984). Deployed collector v4, Sheet v3; Crypto/FX dry runs and live Sheet readback HTTP 200, four historic Stock rows untouched. SQL 29/29 PASS. Next scheduled market session will retry.

## 1.0.0 — 2026-10-30: Crypto/FX price-only cutover and legacy cleanup

- Crypto+FX price collection and Google Sheet sync verified HTTP 200.
- Five canonical price/identity tables and six required SQL routines left; user manually deleted the old 87-table archive without backup, seven orphaned trigger routines retired.
- Sixteen old 410 Edge tombstones await physical removal.
