# Changelog — Asset Price Data Service

## 1.1.0 — 2026-10-30: Held US Stock EOD extension (candidate)

- Add Alpha Vantage daily unadjusted close to the two supported price-only workers for OPEN Stock symbols from Google Sheet. Four held symbols initially: MSFT, NVDA, TLN, TTWO.
- Strict current NY trading-date verification, provider identity, positive prices, secret-safe provenance, atomic observation persistence and read-only holdings.
- Sheet worker syncs only newly certified Stock EOD observations, preserving all non-eligible historical stock rows and all crypto/FX/holdings protections.
- Propose weekday 19:00 ET EOD collection and 19:30 ET Sheet follow-up, DST-safe without changing existing schedules.
- **Activation is gated on API key validation and actual post-close end-to-end verification.**

## 1.0.0 — 2026-10-30: Crypto/FX price-only cutover and legacy cleanup

- Crypto+FX price collection and Google Sheet sync verified HTTP 200.
- Five canonical price/identity tables and six required SQL routines left; user manually deleted the old 87-table archive without backup, seven orphaned trigger routines retired.
- Sixteen old 410 Edge tombstones await physical removal.
